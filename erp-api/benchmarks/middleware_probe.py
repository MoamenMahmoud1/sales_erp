"""Benchmark-only per-middleware wall-clock attribution.

This module monkey-patches the configured middleware classes only when explicitly
requested by BENCH_MIDDLEWARE_DIAGNOSTIC=1. It preserves real async middleware
classification and records per-request inclusive spans in entry order.
"""

from __future__ import annotations

import inspect
import time
from functools import wraps


def _begin_span(metrics: dict, name: str) -> dict:
    trace = metrics.setdefault("middleware_trace", [])
    span = {"name": name, "started": time.perf_counter(), "inclusive_ms": None}
    trace.append(span)
    return span


def _finish_span(span: dict) -> None:
    span["inclusive_ms"] = (time.perf_counter() - span["started"]) * 1000
    span.pop("started", None)


def _wrap_sync_call(original, name: str):
    @wraps(original)
    def wrapper(self, request, *args, **kwargs):
        from benchmarks.request_timing_middleware import _metrics

        metrics = _metrics.get()
        if metrics is None:
            return original(self, request, *args, **kwargs)

        span = _begin_span(metrics, name)
        try:
            result = original(self, request, *args, **kwargs)
        except BaseException:
            _finish_span(span)
            raise

        if inspect.isawaitable(result):
            async def finish_async():
                try:
                    return await result
                finally:
                    _finish_span(span)

            return finish_async()

        _finish_span(span)
        return result

    return wrapper


def _wrap_async_call(original, name: str):
    @wraps(original)
    async def wrapper(self, request, *args, **kwargs):
        from benchmarks.request_timing_middleware import _metrics

        metrics = _metrics.get()
        if metrics is None:
            return await original(self, request, *args, **kwargs)

        span = _begin_span(metrics, name)
        try:
            return await original(self, request, *args, **kwargs)
        finally:
            _finish_span(span)

    return wrapper


def install_middleware_probe(middleware_paths: list[str]) -> None:
    """Patch configured middleware classes for benchmark-only attribution."""
    for path in middleware_paths:
        if path == "benchmarks.request_timing_middleware.BenchmarkTimingMiddleware":
            continue

        module_name, class_name = path.rsplit(".", 1)
        module = __import__(module_name, fromlist=[class_name])
        cls = getattr(module, class_name)
        if getattr(cls, "_benchmark_probe_installed", False):
            continue

        original = cls.__call__
        qualified_name = f"{cls.__module__}.{cls.__qualname__}"
        if inspect.iscoroutinefunction(original):
            wrapped = _wrap_async_call(original, qualified_name)
        else:
            wrapped = _wrap_sync_call(original, qualified_name)
        cls.__call__ = wrapped
        cls._benchmark_probe_installed = True
