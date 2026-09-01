"""Low-overhead per-request timing for async performance experiments."""

from __future__ import annotations

import time
from contextlib import contextmanager
from contextvars import ContextVar


class PerfTiming:
    def __init__(self) -> None:
        self.started_ns = time.perf_counter_ns()
        self.admission_wait_ns = 0
        self.pool_wait_ns = 0
        self.db_operation_ns = 0
        self.db_operation_count = 0
        self.serializer_wait_ns = 0
        self.serializer_cpu_ns = 0

    @property
    def total_ns(self) -> int:
        return time.perf_counter_ns() - self.started_ns

    @property
    def app_ns(self) -> int:
        # db_operation already contains admission + pool + SQL/ORM execution,
        # so those sub-stages must not be subtracted a second time.
        return max(
            self.total_ns
            - self.db_operation_ns
            - self.serializer_wait_ns
            - self.serializer_cpu_ns,
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


def add_db_operation(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.db_operation_ns += max(ns, 0)
        timing.db_operation_count += 1


def add_serializer_wait(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.serializer_wait_ns += max(ns, 0)


def add_serializer_cpu(ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.serializer_cpu_ns += max(ns, 0)


_pool_instrumented: set[int] = set()


def install_pool_instrumentation() -> None:
    """Measure actual psycopg pool checkout duration."""
    from django.db import connection

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
def db_operation():
    started = time.perf_counter_ns()
    try:
        yield
    finally:
        add_db_operation(time.perf_counter_ns() - started)
