"""Core middleware: proxy trusted headers, request ids, and perf timings."""
import logging
import uuid
from contextvars import ContextVar
from inspect import iscoroutinefunction, markcoroutinefunction

from django.conf import settings
from django.db import connection

from core.proxy import is_trusted_proxy, normalize_ip
from common.services.perf_timing import execute_wrapper, start

CORRELATION_HEADER = "HTTP_X_REQUEST_ID"

_current_request_id: ContextVar[str | None] = ContextVar(
    "erp_request_id", default=None
)


def get_current_request_id() -> str | None:
    """Return the request id of the current request (or ``None``)."""
    return _current_request_id.get()


class _RequestIdFilter(logging.Filter):
    """Add ``request_id`` to every log record for structured formatters."""

    def filter(self, record):
        record.request_id = get_current_request_id() or "-"
        return True


class _RequestIdLogRecordFactory:
    """Wrap the default LogRecord factory to inject ``request_id``."""

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
    """Keep the ASGI path async and expose four measurable server stages.

    The timings are opt-in through PERF_TIMING_ENABLED. The headers are useful
    for an external benchmark because they are emitted by the application and
    do not require Django debug instrumentation.
    """

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
                return self.get_response(request)
            timing = start()
            with execute_wrapper(connection):
                response = self.get_response(request)
            self._add_headers(response, timing)
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
                timing = start()
                with execute_wrapper(connection):
                    response = await self.get_response(request)
                self._add_headers(response, timing)
            response["X-Request-Id"] = request_id
            return response
        finally:
            _current_request_id.reset(token)

    @staticmethod
    def _add_headers(response, timing):
        response["X-Perf-Total-ms"] = f"{timing.as_ms(timing.total_ns):.3f}"
        response["X-Perf-App-ms"] = f"{timing.as_ms(timing.app_ns):.3f}"
        response["X-Perf-DB-Admission-ms"] = f"{timing.as_ms(timing.admission_wait_ns):.3f}"
        response["X-Perf-DB-Pool-ms"] = f"{timing.as_ms(timing.pool_wait_ns):.3f}"
        response["X-Perf-SQL-ms"] = f"{timing.as_ms(timing.sql_ns):.3f}"
        response["X-Perf-SQL-Count"] = str(timing.sql_count)
        response["Server-Timing"] = (
            f"app;dur={timing.as_ms(timing.app_ns):.3f},"
            f"db-admission;dur={timing.as_ms(timing.admission_wait_ns):.3f},"
            f"db-pool;dur={timing.as_ms(timing.pool_wait_ns):.3f},"
            f"sql;dur={timing.as_ms(timing.sql_ns):.3f}"
        )


class RequestCorrelationMiddleware:
    """Hybrid middleware that preserves the ASGI async path without adaptation."""

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
    """Hybrid middleware that normalizes forwarded headers without sync adaptation."""

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
