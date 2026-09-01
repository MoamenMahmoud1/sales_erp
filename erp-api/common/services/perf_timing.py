"""Low-overhead per-request timing for async DB admission experiments."""

from __future__ import annotations

import time
from contextlib import contextmanager
from contextvars import ContextVar

from django.db import connection


class PerfTiming:
    def __init__(self) -> None:
        self.started_ns = time.perf_counter_ns()
        self.admission_wait_ns = 0
        self.pool_wait_ns = 0
        self.sql_ns = 0
        self.sql_count = 0

    @property
    def total_ns(self) -> int:
        return time.perf_counter_ns() - self.started_ns

    @property
    def app_ns(self) -> int:
        return max(
            self.total_ns
            - self.admission_wait_ns
            - self.pool_wait_ns
            - self.sql_ns,
            0,
        )

    @staticmethod
    def as_ms(value_ns: int) -> float:
        return value_ns / 1_000_000.0


_current: ContextVar[PerfTiming | None] = ContextVar(
    "erp_perf_timing", default=None
)


def start() -> PerfTiming:
    timing = PerfTiming()
    _current.set(timing)
    return timing


def current() -> PerfTiming | None:
    return _current.get()


def add_admission_wait(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.admission_wait_ns += max(ns, 0)


def add_pool_wait(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.pool_wait_ns += max(ns, 0)


def add_sql(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.sql_ns += max(ns, 0)
        timing.sql_count += 1


class TimingExecuteWrapper:
    """Measure cursor execution time, excluding connection-pool acquisition."""

    def __call__(self, execute, sql, params, many, context):
        started = time.perf_counter_ns()
        try:
            return execute(sql, params, many, context)
        finally:
            add_sql(time.perf_counter_ns() - started)


_pool_instrumented = set()


def install_pool_instrumentation() -> None:
    """Wrap Django's psycopg ConnectionPool.getconn() once per pool object.

    Django's PostgreSQL backend checks out a synchronous psycopg connection
    from ConnectionPool.getconn() inside its async ORM adapter. ContextVars
    are propagated across that adapter, so mutating the request's timing object
    here gives us the actual pool queue/check-out duration rather than an
    inferred remainder.
    """
    pool = getattr(connection, "pool", None)
    if pool is None:
        return

    marker = id(pool)
    if marker in _pool_instrumented:
        return

    original = pool.getconn

    def timed_getconn(timeout=None):
        started = time.perf_counter_ns()
        try:
            return original(timeout)
        finally:
            add_pool_wait(time.perf_counter_ns() - started)

    pool.getconn = timed_getconn
    _pool_instrumented.add(marker)


@contextmanager
def execute_wrapper(connection):
    with connection.execute_wrapper(TimingExecuteWrapper()):
        yield
