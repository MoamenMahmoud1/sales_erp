"""Benchmark-only middleware that creates an explicit boundary around the view."""

from __future__ import annotations

import inspect
import os
import time

from asgiref.sync import markcoroutinefunction

from benchmarks.request_timing_middleware import _metrics


class BenchmarkViewBoundaryMiddleware:
    """Measure the view/handler section separately from middleware."""

    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        self._is_async = inspect.iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def __call__(self, request):
        if os.getenv("BENCH_MIDDLEWARE_DIAGNOSTIC", "0") != "1":
            return self.get_response(request)

        metrics = _metrics.get()
        if metrics is None:
            return self.get_response(request)

        span = {
            "name": "__view_boundary__",
            "started": time.perf_counter(),
            "inclusive_ms": None,
        }
        metrics.setdefault("middleware_trace", []).append(span)

        if self._is_async:
            return self._async_call(request, span)

        try:
            return self.get_response(request)
        finally:
            span["inclusive_ms"] = (time.perf_counter() - span["started"]) * 1000
            span.pop("started", None)

    async def _async_call(self, request, span):
        try:
            return await self.get_response(request)
        finally:
            span["inclusive_ms"] = (time.perf_counter() - span["started"]) * 1000
            span.pop("started", None)
