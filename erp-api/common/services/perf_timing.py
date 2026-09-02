"""Low-overhead per-request timing for async performance experiments."""

from __future__ import annotations

import threading
import time
from collections import defaultdict
from contextlib import contextmanager
from contextvars import ContextVar


class PerfTiming:
    def __init__(self) -> None:
        self.started_ns = time.perf_counter_ns()
        self.admission_wait_ns = 0
        self.pool_wait_ns = 0
        self.db_operation_ns = 0
        self.db_operation_count = 0
        self.sql_samples: list[dict[str, object]] = []
        self.serializer_wait_ns = 0
        self.serializer_cpu_ns = 0
        self.view_stage_ns: dict[str, int] = {}

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

    def sql_stats(self) -> dict[str, dict[str, float | int]]:
        grouped: dict[str, dict[str, float | int]] = defaultdict(
            lambda: {"count": 0, "total_ms": 0.0, "max_ms": 0.0}
        )
        for sample in self.sql_samples:
            kind = str(sample["kind"])
            duration_ms = float(sample["duration_ms"])
            row = grouped[kind]
            row["count"] += 1
            row["total_ms"] += duration_ms
            row["max_ms"] = max(float(row["max_ms"]), duration_ms)
        return dict(grouped)


_current: ContextVar[PerfTiming | None] = ContextVar(
    "erp_perf_timing", default=None
)


def start() -> PerfTiming:
    timing = PerfTiming()
    _current.set(timing)
    install_sql_instrumentation()
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


def add_view_stage(name: str, ns: int) -> None:
    """Accumulate wall-clock time for an individual view stage."""
    timing = current()
    if timing is not None:
        timing.view_stage_ns[name] = timing.view_stage_ns.get(name, 0) + max(ns, 0)


def _classify_sql(sql: object) -> str:
    normalized = " ".join(str(sql).split()).lower()
    if normalized.startswith("select count("):
        return "count"

    has_stock = "inventory_stockbalance" in normalized
    has_sold = "invoices_invoiceitem" in normalized
    has_product = "products_product" in normalized

    if has_product and (has_stock or has_sold):
        return "product_page_with_metrics"
    if has_stock:
        return "stock"
    if has_sold:
        return "sold"
    return "other"


_sql_patch_lock = threading.Lock()
_sql_patched = False
_original_execute = None
_original_executemany = None


def _record_sql(sql, params, duration_ns: int) -> None:
    timing = current()
    if timing is None:
        return
    timing.sql_samples.append(
        {
            "kind": _classify_sql(sql),
            "duration_ms": duration_ns / 1_000_000.0,
            "sql": " ".join(str(sql).split()),
            "params_repr": repr(params),
        }
    )


def _timed_execute(self, sql, params=None):
    started = time.perf_counter_ns()
    try:
        return _original_execute(self, sql, params)
    finally:
        _record_sql(sql, params, time.perf_counter_ns() - started)


def _timed_executemany(self, sql, param_list):
    started = time.perf_counter_ns()
    try:
        return _original_executemany(self, sql, param_list)
    finally:
        _record_sql(sql, param_list, time.perf_counter_ns() - started)


def install_sql_instrumentation() -> None:
    """Install one lightweight CursorWrapper timing patch for benchmark runs."""
    global _sql_patched, _original_execute, _original_executemany
    if _sql_patched:
        return
    with _sql_patch_lock:
        if _sql_patched:
            return
        from django.db.backends.utils import CursorWrapper

        _original_execute = CursorWrapper.execute
        _original_executemany = CursorWrapper.executemany
        CursorWrapper.execute = _timed_execute
        CursorWrapper.executemany = _timed_executemany
        _sql_patched = True


@contextmanager
def view_stage(name: str):
    """Measure one non-overlapping or nested stage inside a view."""
    started = time.perf_counter_ns()
    try:
        yield
    finally:
        add_view_stage(name, time.perf_counter_ns() - started)


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
