"""Per-worker bounded concurrency gate for async ORM database work."""

from __future__ import annotations

import asyncio
import time
from contextlib import asynccontextmanager

from django.conf import settings

from common.services.perf_timing import add_admission_wait


class DBAdmissionTimeout(RuntimeError):
    """Raised when DB-bound work cannot enter the application gate in time."""


_gate: asyncio.Semaphore | None = None
_gate_loop: asyncio.AbstractEventLoop | None = None
_gate_limit: int | None = None


def _limit() -> int:
    return max(int(getattr(settings, "ASYNC_DB_CONCURRENCY", 0) or 0), 0)


def _timeout_seconds() -> float | None:
    milliseconds = max(
        int(getattr(settings, "ASYNC_DB_ADMISSION_TIMEOUT_MS", 0) or 0),
        0,
    )
    return None if milliseconds == 0 else milliseconds / 1000.0


def enabled() -> bool:
    return _limit() > 0


def _get_gate() -> asyncio.Semaphore:
    global _gate, _gate_loop, _gate_limit
    limit = _limit()
    if limit <= 0:
        raise RuntimeError("async DB gate requested while disabled")

    loop = asyncio.get_running_loop()
    if _gate is None or _gate_limit != limit or _gate_loop is not loop:
        _gate = asyncio.Semaphore(limit)
        _gate_limit = limit
        _gate_loop = loop
    return _gate


async def _acquire_gate(gate: asyncio.Semaphore, timeout: float | None) -> None:
    started = time.perf_counter_ns()
    try:
        if timeout is None:
            await gate.acquire()
        else:
            await asyncio.wait_for(gate.acquire(), timeout=timeout)
    except TimeoutError as exc:
        add_admission_wait(time.perf_counter_ns() - started)
        raise DBAdmissionTimeout from exc
    else:
        add_admission_wait(time.perf_counter_ns() - started)


@asynccontextmanager
async def db_slot():
    """Bound DB-bound ORM concurrency per ASGI worker.

    The admission timer covers only semaphore queueing. The pool timer covers
    psycopg ConnectionPool.getconn() checkout. The DB-operation timer wraps
    the complete async pagination/database await, including Django's async
    ORM adapter and result materialization. PostgreSQL execution plans and
    pg_stat_statements provide server-side SQL timing separately.
    """
    if not enabled():
        yield
        return

    gate = _get_gate()
    timeout = _timeout_seconds()
    await _acquire_gate(gate, timeout)

    try:
        yield
    finally:
        gate.release()
