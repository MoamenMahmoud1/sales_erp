"""Low-overhead per-request timing for async performance experiments."""

from __future__ import annotations

import functools
import inspect
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
        self.transaction_samples: list[dict[str, object]] = []
        self.function_samples: dict[str, list[float]] = defaultdict(list)
        self.serializer_wait_ns = 0
        self.serializer_cpu_ns = 0
        self.view_stage_ns: dict[str, int] = {}

    @property
    def total_ns(self) -> int:
        return time.perf_counter_ns() - self.started_ns

    @property
    def app_ns(self) -> int:
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

    def transaction_stats(self) -> dict[str, dict[str, float | int]]:
        grouped: dict[str, dict[str, float | int]] = defaultdict(
            lambda: {"count": 0, "total_ms": 0.0, "max_ms": 0.0}
        )
        for sample in self.transaction_samples:
            kind = str(sample["kind"])
            duration_ms = float(sample["duration_ms"])
            row = grouped[kind]
            row["count"] += 1
            row["total_ms"] += duration_ms
            row["max_ms"] = max(float(row["max_ms"]), duration_ms)
        return dict(grouped)

    def function_stats(self) -> dict[str, dict[str, float | int]]:
        output = {}
        for name, samples in self.function_samples.items():
            output[name] = {
                "count": len(samples),
                "total_ms": sum(samples),
                "mean_ms": sum(samples) / len(samples),
                "max_ms": max(samples),
            }
        return output


_current: ContextVar[PerfTiming | None] = ContextVar("erp_perf_timing", default=None)
_transaction_stack: ContextVar[tuple[int, ...]] = ContextVar(
    "erp_perf_transaction_stack", default=()
)


def start() -> PerfTiming:
    timing = PerfTiming()
    _current.set(timing)
    install_sql_instrumentation()
    install_transaction_instrumentation()
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
    timing = current()
    if timing is not None:
        timing.view_stage_ns[name] = timing.view_stage_ns.get(name, 0) + max(ns, 0)


def add_function_time(name: str, ns: int) -> None:
    timing = current()
    if timing is not None:
        timing.function_samples[name].append(ns / 1_000_000.0)


def timed_function(name: str | None = None):
    """Measure one complete sync or async function invocation."""
    def decorator(func):
        metric_name = name or f"{func.__module__}.{func.__qualname__}"
        if inspect.iscoroutinefunction(func):
            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs):
                started = time.perf_counter_ns()
                try:
                    return await func(*args, **kwargs)
                finally:
                    add_function_time(metric_name, time.perf_counter_ns() - started)
            return async_wrapper

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            started = time.perf_counter_ns()
            try:
                return func(*args, **kwargs)
            finally:
                add_function_time(metric_name, time.perf_counter_ns() - started)
        return sync_wrapper
    return decorator


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
    timing.sql_samples.append({
        "kind": _classify_sql(sql),
        "duration_ms": duration_ns / 1_000_000.0,
        "sql": " ".join(str(sql).split()),
        "params_repr": repr(params),
    })


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


_transaction_patch_lock = threading.Lock()
_transaction_patched = False
_original_atomic_enter = None
_original_atomic_exit = None


def _transaction_enter(self):
    started = time.perf_counter_ns()
    result = _original_atomic_enter(self)
    stack = _transaction_stack.get()
    _transaction_stack.set(stack + (started,))
    return result


def _transaction_exit(self, exc_type, exc_value, traceback):
    stack = _transaction_stack.get()
    started = stack[-1] if stack else time.perf_counter_ns()
    try:
        return _original_atomic_exit(self, exc_type, exc_value, traceback)
    finally:
        _transaction_stack.set(stack[:-1] if stack else ())
        timing = current()
        if timing is not None:
            depth = len(stack)
            timing.transaction_samples.append({
                "kind": "transaction" if depth == 1 else "savepoint",
                "duration_ms": (time.perf_counter_ns() - started) / 1_000_000.0,
                "depth": depth,
            })


def install_transaction_instrumentation() -> None:
    global _transaction_patched, _original_atomic_enter, _original_atomic_exit
    if _transaction_patched:
        return
    with _transaction_patch_lock:
        if _transaction_patched:
            return
        from django.db.transaction import Atomic
        _original_atomic_enter = Atomic.__enter__
        _original_atomic_exit = Atomic.__exit__
        Atomic.__enter__ = _transaction_enter
        Atomic.__exit__ = _transaction_exit
        _transaction_patched = True


@contextmanager
def view_stage(name: str):
    started = time.perf_counter_ns()
    try:
        yield
    finally:
        add_view_stage(name, time.perf_counter_ns() - started)


_pool_instrumented: set[int] = set()


def install_pool_instrumentation() -> None:
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
