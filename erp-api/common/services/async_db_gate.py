"""Per-process bounded concurrency gate for async ORM database work.

The gate deliberately sits above Django's database pool. Requests wait here
before entering the DB-bound section, so the pool is not used as the primary
request queue when application concurrency is much higher than safe DB
concurrency.
"""

from __future__ import annotations

import asyncio
import time
from contextlib import asynccontextmanager
from contextvars import ContextVar

from django.conf import settings

_gate: asyncio.Semaphore | None = None
_gate_limit: int | None = None
_gate_wait: ContextVar[float] = ContextVar("async_db_gate_wait", default=0.0)


def _limit() -> int:
    value = int(getattr(settings, "ASYNC_DB_CONCURRENCY", 0) or 0)
    return max(value, 0)


def enabled() -> bool:
    return _limit() > 0


def consume_wait() -> float:
    """Return and clear the current request's accumulated gate wait time."""
    waited = _gate_wait.get()
    _gate_wait.set(0.0)
    return waited


def _get_gate() -> asyncio.Semaphore:
    global _gate, _gate_limit
    limit = _limit()
    if limit <= 0:
        raise RuntimeError("async DB gate requested while disabled")
    if _gate is None or _gate_limit != limit:
        _gate = asyncio.Semaphore(limit)
        _gate_limit = limit
    return _gate


@asynccontextmanager
async def db_slot():
    """Acquire one bounded application-level DB concurrency slot."""
    if not enabled():
        yield
        return

    started = time.perf_counter()
    gate = _get_gate()
    await gate.acquire()
    waited = time.perf_counter() - started
    if waited:
        _gate_wait.set(_gate_wait.get() + waited)
    try:
        yield
    finally:
        gate.release()
