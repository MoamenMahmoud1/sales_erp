"""Benchmark-only request, SQL, and DB-pool timing instrumentation."""

import inspect
import time
from contextvars import ContextVar

from asgiref.sync import markcoroutinefunction
from django.db.backends.signals import connection_created
from django.dispatch import receiver

_metrics: ContextVar[dict | None] = ContextVar("benchmark_metrics", default=None)


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


def _install_wrapper(connection):
    if getattr(connection, "_benchmark_wrapper_installed", False):
        return
    connection.execute_wrappers.append(TimingWrapper())
    connection._benchmark_wrapper_installed = True


@receiver(connection_created)
def _connection_created(sender, connection, **kwargs):
    _install_wrapper(connection)


class BenchmarkTimingMiddleware:
    """Measure request wall time, SQL execution time, and derived app time.

    Pool acquisition is intentionally not counted as SQL time. If the backend
    exposes pool wait telemetry, benchmark code can add it to the same metrics
    context without conflating it with PostgreSQL execution time.
    """

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
        }
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
        pool_wait_ms = metrics["pool_wait"] * 1000
        response["Server-Timing"] = (
            f"app;dur={max(total_ms - db_ms - pool_wait_ms, 0):.3f}, "
            f"db;dur={db_ms:.3f}, pool;dur={pool_wait_ms:.3f}, "
            f"dbq;desc=queries;dur={metrics['db_queries']}"
        )
        response["X-Benchmark-Request-Ms"] = f"{total_ms:.3f}"
        response["X-Benchmark-DB-Ms"] = f"{db_ms:.3f}"
        response["X-Benchmark-DB-Queries"] = str(metrics["db_queries"])
        response["X-Benchmark-Pool-Wait-Ms"] = f"{pool_wait_ms:.3f}"
        _metrics.reset(token)
