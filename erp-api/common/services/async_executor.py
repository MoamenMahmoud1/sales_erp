"""Bounded executor for synchronous work inside async benchmark paths.

The production async stack keeps Django's normal thread-sensitive ORM adapter.
When ASYNC_BENCH_THREADS is set, benchmark runs can explicitly cap the number
of worker threads used for read-only ORM/serializer work so Async is not
compared as a one-thread process against a multi-thread sync process.
"""

from __future__ import annotations

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from typing import Any, Callable

from asgiref.sync import sync_to_async


_executor: ThreadPoolExecutor | None = None
_executor_loop: asyncio.AbstractEventLoop | None = None
_executor_size: int | None = None


def configured_threads() -> int:
    value = os.getenv("ASYNC_BENCH_THREADS", "0").strip()
    try:
        return max(int(value or "0"), 0)
    except ValueError as exc:
        raise ValueError("ASYNC_BENCH_THREADS must be an integer >= 0") from exc


def enabled() -> bool:
    return configured_threads() > 0


def _get_executor() -> ThreadPoolExecutor:
    global _executor, _executor_loop, _executor_size

    size = configured_threads()
    if size <= 0:
        raise RuntimeError("benchmark executor requested while disabled")

    loop = asyncio.get_running_loop()
    if _executor is None or _executor_loop is not loop or _executor_size != size:
        if _executor is not None:
            _executor.shutdown(wait=False, cancel_futures=True)
        _executor = ThreadPoolExecutor(
            max_workers=size,
            thread_name_prefix="async-bench",
        )
        _executor_loop = loop
        _executor_size = size
    return _executor


async def run_sync(func: Callable[..., Any], /, *args: Any, **kwargs: Any) -> Any:
    """Run sync work on the bounded benchmark executor when enabled."""

    if not enabled():
        return await sync_to_async(func, thread_sensitive=True)(*args, **kwargs)

    call = partial(func, *args, **kwargs)
    return await sync_to_async(
        call,
        thread_sensitive=False,
        executor=_get_executor(),
    )()
