"""Benchmark-only per-middleware wall-clock attribution.

This module monkey-patches the configured middleware classes only when explicitly
requested by BENCH_MIDDLEWARE_DIAGNOSTIC=1. It preserves real async middleware
classification and records inclusive timings for each middleware invocation.
The outer benchmark middleware later derives exclusive self-time by subtracting
the next inner middleware's inclusive time.
"""

from __future__ import annotations

import inspect
import time
from functools import wraps


def _record(metrics: dict, name: str, started: float) -> None:
    elapsed_ms = (time.perf_counter() - started) * 1000
    spans = metrics.setdefault("middleware_spans", {})
    entry = spans.get(name)
    if entry is None:
        spans[name] = {"inclusive": elapsed_ms, "count": 1}
    else:
        entry["inclusive"] += elapsed_ms
        entry["count"] += 1


def _wrap_sync_call(original, name: str):
    @wraps(original)
    def wrapper(self, request, *args, **kwargs):
        from benchmarks.request_timing_middleware import _metrics

        metrics = _metrics.get()
        if metrics is None:
            return original(self, request, *args, **kwargs)

        started = time.perf_counter()
        result = original(self, request, *args, **kwargs)
        if inspect.isawaitable(result):
            async def finish_async():
                try:
                    return await result
                finally:
                    _record(metrics, name, started)

            return finish_async()

        _record(metrics, name, started)
        return result

    return wrapper


def _wrap_async_call(original, name: str):
    @wraps(original)
    async def wrapper(self, request, *args, **kwargs):
        from benchmarks.request_timing_middleware import _metrics

        metrics = _metrics.get()
        if metrics is None:
            return await original(self, request, *args, **kwargs)

        started = time.perf_counter()
        try:
            return await original(self, request, *args, **kwargs)
        finally:
            _record(metrics, name, started)

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
