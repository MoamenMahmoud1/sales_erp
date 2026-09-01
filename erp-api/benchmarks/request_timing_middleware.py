"""Benchmark-only request/DB timing instrumentation.

This module is loaded only by settings_bench. It measures wall-clock request
time and SQL execution time without changing production middleware.
"""

import time
from contextvars import ContextVar

from django.db.backends.signals import connection_created
from django.dispatch import receiver

_metrics: ContextVar[dict | None] = ContextVar("benchmark_metrics", default=None)


def _install_wrapper(connection):
    if getattr(connection, "_benchmark_wrapper_installed", False):
        return

    class TimingWrapper:
        def __call__(self, execute, sql, params, many, context):
            started = time.perf_counter()
            try:
                return execute(sql, params, many, context)
            finally:
                elapsed = time.perf_counter() - started
                metrics = _metrics.get()
                if metrics is not None:
                    metrics["db_time"] += elapsed
                    metrics["db_queries"] += 1

    connection.execute_wrapper(TimingWrapper())
    connection._benchmark_wrapper_installed = True


@receiver(connection_created)
def _connection_created(sender, connection, **kwargs):
    _install_wrapper(connection)


class BenchmarkTimingMiddleware:
    """Measure total request wall time and SQL execution time."""

    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        import inspect
        from asgiref.sync import markcoroutinefunction

        self._is_async = inspect.iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def __call__(self, request):
        metrics = {"db_time": 0.0, "db_queries": 0}
        token = _metrics.set(metrics)
        started = time.perf_counter()
        try:
            if self._is_async:
                return self._async_call(request, started, token, metrics)
            response = self.get_response(request)
            self._finish(response, started, token, metrics)
            return response
        except Exception:
            _metrics.reset(token)
            raise

    async def _async_call(self, request, started, token, metrics):
        try:
            response = await self.get_response(request)
            self._finish(response, started, token, metrics)
            return response
        except Exception:
            _metrics.reset(token)
            raise

    def _finish(self, response, started, token, metrics):
        total_ms = (time.perf_counter() - started) * 1000
        db_ms = metrics["db_time"] * 1000
        response["Server-Timing"] = (
            f"app;dur={max(total_ms - db_ms, 0):.3f}, "
            f"db;dur={db_ms:.3f}, dbq;desc=queries;dur={metrics['db_queries']}"
        )
        response["X-Benchmark-Request-Ms"] = f"{total_ms:.3f}"
        response["X-Benchmark-DB-Ms"] = f"{db_ms:.3f}"
        response["X-Benchmark-DB-Queries"] = str(metrics["db_queries"])
        _metrics.reset(token)
