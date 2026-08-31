"""Core middleware: proxy trusted headers + request correlation IDs.

The correlation ID middleware generates (or propagates) a unique request
identifier that flows through every log line, making it possible to trace a
single request across the async/sync boundary and through the sync
transactional core.
"""
import logging
import uuid
from contextvars import ContextVar

from django.conf import settings

from core.proxy import is_trusted_proxy, normalize_ip

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


# Install at import time so log records outside a request still have the
# attribute (value ``"-"``).
logging.setLogRecordFactory(
    _RequestIdLogRecordFactory(logging.getLogRecordFactory())
)
_root = logging.getLogger()
if not any(isinstance(f, _RequestIdFilter) for f in _root.filters):
    _root.addFilter(_RequestIdFilter())


class RequestCorrelationMiddleware:
    """Generate / propagate a request-id stored in the logging context var.

    Downstream sync code running inside ``sync_to_async`` can read
    ``get_current_request_id()`` to attach the same id to its own log
    records.  The response header ``X-Request-Id`` echoes the id back to
    the client.
    """

    response_header = "X-Request-Id"

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request_id = request.META.get(CORRELATION_HEADER) or uuid.uuid4().hex
        request.META[CORRELATION_HEADER] = request_id
        token = _current_request_id.set(request_id)
        try:
            response = self.get_response(request)
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

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        remote_address = normalize_ip(request.META.get("REMOTE_ADDR"))
        trust_headers = (
            getattr(settings, "TRUST_PROXY_HEADERS", False)
            and remote_address is not None
            and is_trusted_proxy(remote_address)
        )
        if not trust_headers:
            for header in self.forwarded_headers:
                request.META.pop(header, None)

        return self.get_response(request)
