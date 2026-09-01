"""Low-overhead per-request timing for async DB admission experiments."""

from __future__ import annotations

import time
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass


@dataclass
class PerfTiming:
    started_ns: int
    admission_wait_ns: int = 0
    pool_wait_ns: int = 0
    sql_ns: int = 0
    sql_count: int = 0

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

    def as_ms(self, value_ns: int) -> float:
        return value_ns / 1_000_000.0


_current: ContextVar[PerfTiming | None] = ContextVar(
    "erp_perf_timing", default=None
)


def start() -> PerfTiming:
    timing = PerfTiming(time.perf_counter_ns())
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
    """Measure only cursor execution/fetch time, excluding pool acquisition."""

    def execute(self, execute, sql, params, many, context):
        started = time.perf_counter_ns()
        try:
            return execute(sql, params, many, context)
        finally:
            add_sql(time.perf_counter_ns() - started)

    def executemany(self, execute, sql, param_list, context):
        started = time.perf_counter_ns()
        try:
            return execute(sql, param_list, context)
        finally:
            add_sql(time.perf_counter_ns() - started)

    def callproc(self, execute, name, params, many, context):
        started = time.perf_counter_ns()
        try:
            return execute(name, params, many, context)
        finally:
            add_sql(time.perf_counter_ns() - started)


@contextmanager
def execute_wrapper(connection):
    with connection.execute_wrapper(TimingExecuteWrapper()):
        yield
