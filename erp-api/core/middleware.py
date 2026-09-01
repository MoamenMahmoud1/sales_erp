"""Core middleware: proxy headers, request ids, and perf timings."""
import logging
import uuid
from contextvars import ContextVar
from inspect import iscoroutinefunction, markcoroutinefunction

from django.conf import settings

from core.proxy import is_trusted_proxy, normalize_ip
from common.services.perf_timing import install_pool_instrumentation, start

CORRELATION_HEADER = "HTTP_X_REQUEST_ID"

_current_request_id: ContextVar[str | None] = ContextVar(
    "erp_request_id", default=None
)


def get_current_request_id() -> str | None:
    return _current_request_id.get()


class _RequestIdLogRecordFactory:
    def __init__(self, factory):
        self._factory = factory

    def __call__(self, *args, **kwargs):
        record = self._factory(*args, **kwargs)
        record.request_id = get_current_request_id() or "-"
        return record


logging.setLogRecordFactory(
    _RequestIdLogRecordFactory(logging.getLogRecordFactory())
)


class RequestIdAndPerfMiddleware:
    """Keep the ASGI path async and expose independent server-side stages."""

    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        self._is_async = iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def __call__(self, request):
        if self._is_async:
            return self._async_call(request)

        request_id = request.META.get(CORRELATION_HEADER) or uuid.uuid4().hex
        request.META[CORRELATION_HEADER] = request_id
        token = _current_request_id.set(request_id)
        try:
            if not getattr(settings, "PERF_TIMING_ENABLED", False):
                response = self.get_response(request)
            else:
                install_pool_instrumentation()
                timing = start()
                response = self.get_response(request)
                self._add_headers(response, timing)
            response["X-Request-Id"] = request_id
            return response
        finally:
            _current_request_id.reset(token)

    async def _async_call(self, request):
        request_id = request.META.get(CORRELATION_HEADER) or uuid.uuid4().hex
        request.META[CORRELATION_HEADER] = request_id
        token = _current_request_id.set(request_id)
        try:
            if not getattr(settings, "PERF_TIMING_ENABLED", False):
                response = await self.get_response(request)
            else:
                install_pool_instrumentation()
                timing = start()
                response = await self.get_response(request)
                self._add_headers(response, timing)
            response["X-Request-Id"] = request_id
            return response
        finally:
            _current_request_id.reset(token)

    @staticmethod
    def _add_headers(response, timing):
        ms = timing.as_ms
        response["X-Perf-Total-ms"] = f"{ms(timing.total_ns):.3f}"
        response["X-Perf-App-ms"] = f"{ms(timing.app_ns):.3f}"
        response["X-Perf-DB-Admission-ms"] = f"{ms(timing.admission_wait_ns):.3f}"
        response["X-Perf-DB-Pool-ms"] = f"{ms(timing.pool_wait_ns):.3f}"
        response["X-Perf-DB-Operation-ms"] = f"{ms(timing.db_operation_ns):.3f}"
        response["X-Perf-DB-Operation-Count"] = str(timing.db_operation_count)
        response["X-Perf-Serializer-Wait-ms"] = f"{ms(timing.serializer_wait_ns):.3f}"
        response["X-Perf-Serializer-CPU-ms"] = f"{ms(timing.serializer_cpu_ns):.3f}"
        response["Server-Timing"] = (
            f"app;dur={ms(timing.app_ns):.3f},"
            f"db-admission;dur={ms(timing.admission_wait_ns):.3f},"
            f"db-pool;dur={ms(timing.pool_wait_ns):.3f},"
            f"db-operation;dur={ms(timing.db_operation_ns):.3f},"
            f"serializer-wait;dur={ms(timing.serializer_wait_ns):.3f},"
            f"serializer-cpu;dur={ms(timing.serializer_cpu_ns):.3f}"
        )


class RequestCorrelationMiddleware:
    response_header = "X-Request-Id"
    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        self._is_async = iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def __call__(self, request):
        if self._is_async:
            return self._async_call(request)
        request_id = request.META.get(CORRELATION_HEADER) or uuid.uuid4().hex
        request.META[CORRELATION_HEADER] = request_id
        token = _current_request_id.set(request_id)
        try:
            response = self.get_response(request)
        finally:
            _current_request_id.reset(token)
        response[self.response_header] = request_id
        return response

    async def _async_call(self, request):
        request_id = request.META.get(CORRELATION_HEADER) or uuid.uuid4().hex
        request.META[CORRELATION_HEADER] = request_id
        token = _current_request_id.set(request_id)
        try:
            response = await self.get_response(request)
        finally:
            _current_request_id.reset(token)
        response[self.response_header] = request_id
        return response


class TrustedProxyHeadersMiddleware:
    forwarded_headers = (
        "HTTP_FORWARDED",
        "HTTP_X_FORWARDED_FOR",
        "HTTP_X_FORWARDED_HOST",
        "HTTP_X_FORWARDED_PORT",
        "HTTP_X_FORWARDED_PROTO",
    )

    async_capable = True
    sync_capable = True

    def __init__(self, get_response):
        self.get_response = get_response
        self._is_async = iscoroutinefunction(get_response)
        if self._is_async:
            markcoroutinefunction(self)

    def _strip_headers(self, request):
        remote_address = normalize_ip(request.META.get("REMOTE_ADDR"))
        trust_headers = (
            getattr(settings, "TRUST_PROXY_HEADERS", False)
            and remote_address is not None
            and is_trusted_proxy(remote_address)
        )
        if not trust_headers:
            for header in self.forwarded_headers:
                request.META.pop(header, None)

    def __call__(self, request):
        if self._is_async:
            return self._async_call(request)
        self._strip_headers(request)
        return self.get_response(request)

    async def _async_call(self, request):
        self._strip_headers(request)
        return await self.get_response(request)
