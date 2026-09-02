"""Native asyncio PostgreSQL access for ASGI hot paths.

Django's async ORM API is intentionally convenient, but its QuerySet methods
still bridge a number of database operations through synchronous ORM code. This
module provides an explicit native async path for latency-sensitive reads
without replacing Django's ORM or transactional domain services.

The pool is opened lazily or from ASGI lifespan startup, so it remains safe with
Gunicorn ``preload_app``: no PostgreSQL connections are opened by the master
before workers fork.
"""

from __future__ import annotations

import asyncio
import time
from contextlib import asynccontextmanager
from typing import Any, AsyncIterator, Sequence

from django.conf import settings
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool

from common.services.perf_timing import add_pool_wait, db_operation


_pool: AsyncConnectionPool | None = None
_pool_loop: asyncio.AbstractEventLoop | None = None
_pool_lock: asyncio.Lock | None = None


def enabled() -> bool:
    """Return whether native async PostgreSQL access is enabled."""
    return bool(getattr(settings, "ASYNC_NATIVE_DB", True))


def _db_kwargs() -> dict[str, Any]:
    database = settings.DATABASES["default"]
    options = {
        key: value
        for key, value in database.get("OPTIONS", {}).items()
        if key not in {"pool", "cursor_factory"}
    }
    options.update(
        {
            "dbname": database["NAME"],
            "user": database["USER"],
            "password": database["PASSWORD"],
            "host": database.get("HOST") or "localhost",
            "port": database.get("PORT") or "5432",
            "autocommit": True,
            "prepare_threshold": int(getattr(settings, "ASYNC_PG_PREPARE_THRESHOLD", 5)),
            "row_factory": dict_row,
        }
    )
    return options


def _pool_options() -> dict[str, Any]:
    """Build the async pool configuration for one ASGI worker."""
    min_size = max(int(getattr(settings, "ASYNC_PG_POOL_MIN_SIZE", 2)), 0)
    max_size = max(int(getattr(settings, "ASYNC_PG_POOL_MAX_SIZE", 12)), 1)
    max_waiting = max(int(getattr(settings, "ASYNC_PG_MAX_WAITING", 0)), 0)
    if min_size > max_size:
        raise ValueError("ASYNC_PG_POOL_MIN_SIZE must be <= ASYNC_PG_POOL_MAX_SIZE")

    return {
        "min_size": min_size,
        "max_size": max_size,
        "max_waiting": max_waiting,
        "timeout": float(getattr(settings, "ASYNC_PG_POOL_TIMEOUT", 2.0)),
        "max_lifetime": float(getattr(settings, "ASYNC_PG_POOL_MAX_LIFETIME", 3600.0)),
        "max_idle": float(getattr(settings, "ASYNC_PG_POOL_MAX_IDLE", 600.0)),
        "open": False,
        "kwargs": _db_kwargs(),
    }


async def get_pool() -> AsyncConnectionPool:
    """Return the native async pool for the current worker/event loop."""
    global _pool, _pool_loop, _pool_lock

    if not enabled():
        raise RuntimeError("native async PostgreSQL is disabled")

    loop = asyncio.get_running_loop()
    if _pool is not None and _pool_loop is loop:
        return _pool

    if _pool_lock is None or _pool_loop is not loop:
        _pool_lock = asyncio.Lock()
        _pool_loop = loop

    async with _pool_lock:
        if _pool is None or _pool_loop is not loop:
            _pool = AsyncConnectionPool(**_pool_options())
            _pool_loop = loop
            await _pool.open()
        return _pool


async def open_pool(*, wait: bool = True) -> None:
    """Open, pre-warm, and health-check the pool during ASGI startup."""
    if not enabled():
        return
    pool = await get_pool()
    if wait:
        await pool.wait()
    await pool.check()


async def close_pool() -> None:
    """Close the current worker's native async pool."""
    global _pool, _pool_loop, _pool_lock
    pool = _pool
    _pool = None
    _pool_loop = None
    _pool_lock = None
    if pool is not None:
        await pool.close()


@asynccontextmanager
async def connection() -> AsyncIterator[Any]:
    """Acquire an async PostgreSQL connection and return it to the pool."""
    pool = await get_pool()
    started = time.perf_counter_ns()
    acquired = False
    try:
        async with pool.connection() as conn:
            add_pool_wait(time.perf_counter_ns() - started)
            acquired = True
            yield conn
    except Exception:
        if not acquired:
            add_pool_wait(time.perf_counter_ns() - started)
        raise


async def fetch_all(
    query: str,
    params: Sequence[Any] | None = None,
) -> list[dict[str, Any]]:
    """Execute a native async read and return mappings."""
    async with connection() as conn:
        with db_operation():
            async with conn.cursor() as cursor:
                await cursor.execute(query, params)
                return await cursor.fetchall()


async def fetch_one(
    query: str,
    params: Sequence[Any] | None = None,
) -> dict[str, Any] | None:
    """Execute a native async read and return one mapping or ``None``."""
    async with connection() as conn:
        with db_operation():
            async with conn.cursor() as cursor:
                await cursor.execute(query, params)
                return await cursor.fetchone()


__all__ = (
    "close_pool",
    "connection",
    "enabled",
    "fetch_all",
    "fetch_one",
    "get_pool",
    "open_pool",
)
