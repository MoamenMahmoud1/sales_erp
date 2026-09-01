"""Benchmark-only request, SQL, pool, stack, and ORM timing instrumentation."""

import asyncio
import inspect
import time
from contextvars import ContextVar

from asgiref.sync import markcoroutinefunction
from django.db import connection
from django.db.backends.signals import connection_created
from django.dispatch import receiver

_metrics: ContextVar[dict | None] = ContextVar("benchmark_metrics", default=None)

ASYNC_ROUTER_ACTIONS = {
    "alist",
    "aretrieve",
    "acreate",
    "aupdate",
    "apatch",
    "adestroy",
}


def mark_async_orm_operation(operation: str) -> None:
    """Record an async ORM operation in the active benchmark request context."""
    metrics = _metrics.get()
    if metrics is not None:
        metrics.setdefault("async_orm_ops", set()).add(operation)


def _resolved_view_metadata(request):
    resolver = getattr(request, "resolver_match", None)
    func = getattr(resolver, "func", None)
    view_class = getattr(func, "view_class", None)
    actions = getattr(func, "actions", {}) or {}
    action = actions.get(request.method.lower())
    async_callable = bool(func and inspect.iscoroutinefunction(func))
    router = "adrf" if action in ASYNC_ROUTER_ACTIONS else "drf"
    async_handler = bool(async_callable and action in ASYNC_ROUTER_ACTIONS)
    class_name = f"{view_class.__module__}.{view_class.__name__}" if view_class else ""
    return {
        "stack": "async" if async_callable else "sync",
        "router": router,
        "handler": action or "",
        "async_callable": "1" if async_callable else "0",
        "async_handler": "1" if async_handler else "0",
        "view_class": class_name,
    }


class TimingWrapper:
    def __call__(self, execute, sql, params, many, context):
        started = time.perf_counter()
        try:
            return execute(sql, params, many, context)
        finally:
            metrics = _metrics.get()
            if metrics is not None:
                metrics["db_time"] += time.perf_counter() - started
                metrics["db_queries"] += 1


def _pool_stats(connection):
    pool = getattr(connection, "pool", None)
    if pool is None or not hasattr(pool, "get_stats"):
        return {}
    try:
        return pool.get_stats()
    except Exception:
        return {}


def _install_pool_wrapper(connection):
    """Measure real time blocked in Django's psycopg pool acquisition."""
    pool = getattr(connection, "pool", None)
    if pool is None or getattr(pool, "_benchmark_getconn_wrapped", False):
        return

    original_getconn = pool.getconn

    def timed_getconn(*args, **kwargs):
        started = time.perf_counter()
        try:
            return original_getconn(*args, **kwargs)
        finally:
            metrics = _metrics.get()
            if metrics is not None:
                metrics["pool_wait"] += time.perf_counter() - started

    pool.getconn = timed_getconn
    pool._benchmark_getconn_wrapped = True


def _install_wrapper(connection):
    if not getattr(connection, "_benchmark_wrapper_installed", False):
        connection.execute_wrappers.append(TimingWrapper())
        connection._benchmark_wrapper_installed = True
    _install_pool_wrapper(connection)


@receiver(connection_created)
def _connection_created(sender, connection, **kwargs):
    _install_wrapper(connection)


class BenchmarkTimingMiddleware:
    """Measure request wall time, SQL time, pool wait, DB gate wait, and stack."""

    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        self._is_async = inspect.iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def __call__(self, request):
        metrics = {
            "db_time": 0.0,
            "db_queries": 0,
            "pool_wait": 0.0,
            "async_orm_ops": set(),
        }
        token = _metrics.set(metrics)
        started = time.perf_counter()
        try:
            if self._is_async:
                return self._async_call(request, started, token, metrics)
            response = self.get_response(request)
            self._finish(request, response, started, token, metrics, event_loop=False)
            return response
        except Exception:
            _metrics.reset(token)
            raise

    async def _async_call(self, request, started, token, metrics):
        try:
            response = await self.get_response(request)
            self._finish(request, response, started, token, metrics, event_loop=True)
            return response
        except Exception:
            _metrics.reset(token)
            raise

    def _finish(self, request, response, started, token, metrics, *, event_loop):
        total_ms = (time.perf_counter() - started) * 1000
        db_ms = metrics["db_time"] * 1000
        pool_wait_ms = metrics["pool_wait"] * 1000
        gate_wait_ms = float(getattr(request, "_benchmark_db_gate_wait_ms", 0.0) or 0.0)
        pool_stats = _pool_stats(connection)
        view_meta = _resolved_view_metadata(request)
        async_orm_ops = sorted(metrics.get("async_orm_ops", set()))
        serializer_path = getattr(request, "_benchmark_serializer_path", "")

        response["Server-Timing"] = (
            f"app;dur={max(total_ms - db_ms - pool_wait_ms - gate_wait_ms, 0):.3f}, "
            f"db;dur={db_ms:.3f}, pool;dur={pool_wait_ms:.3f}, gate;dur={gate_wait_ms:.3f}, "
            f"dbq;desc=queries;dur={metrics['db_queries']}"
        )
        response["X-Benchmark-Request-Ms"] = f"{total_ms:.3f}"
        response["X-Benchmark-DB-Ms"] = f"{db_ms:.3f}"
        response["X-Benchmark-DB-Queries"] = str(metrics["db_queries"])
        response["X-Benchmark-Pool-Wait-Ms"] = f"{pool_wait_ms:.3f}"
        response["X-Benchmark-DB-Gate-Wait-Ms"] = f"{gate_wait_ms:.3f}"
        response["X-Benchmark-DB-Gate-Limit"] = str(
            getattr(__import__("django.conf", fromlist=["settings"]).settings, "ASYNC_DB_CONCURRENCY", 0)
        )
        response["X-Benchmark-Pool-Size"] = str(pool_stats.get("pool_size", 0))
        response["X-Benchmark-Pool-Available"] = str(pool_stats.get("pool_available", 0))
        response["X-Benchmark-Pool-Requests-Waiting"] = str(pool_stats.get("requests_waiting", 0))
        response["X-Benchmark-Pool-Requests-Queued"] = str(pool_stats.get("requests_queued", 0))
        response["X-Benchmark-Pool-Requests-Wait-Ms"] = str(pool_stats.get("requests_wait_ms", 0))
        response["X-Benchmark-Stack"] = view_meta["stack"]
        response["X-Benchmark-Router"] = view_meta["router"]
        response["X-Benchmark-Handler"] = view_meta["handler"]
        response["X-Benchmark-Async-Callable"] = view_meta["async_callable"]
        response["X-Benchmark-Async-Handler"] = view_meta["async_handler"]
        response["X-Benchmark-View-Class"] = view_meta["view_class"]
        response["X-Benchmark-Event-Loop"] = "1" if event_loop else "0"
        response["X-Benchmark-Async-ORM-Ops"] = ",".join(async_orm_ops)
        response["X-Benchmark-Serializer-Path"] = serializer_path

        if event_loop:
            try:
                asyncio.get_running_loop()
            except RuntimeError:
                response["X-Benchmark-Event-Loop"] = "0"

        _metrics.reset(token)
