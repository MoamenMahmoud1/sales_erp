"""
Observability helpers for business-operation logging.

Every critical business operation logs a structured line that includes the
request correlation id (when available), the acting user, the operation name,
and contextual attributes.  This does NOT log sensitive financial values,
passwords, tokens, or PII beyond what is needed to identify the object.
"""
import logging

from core.middleware import get_current_request_id  # noqa: F401

logger = logging.getLogger("erp.operations")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter(
            "{asctime} {levelname} {name} [{request_id}] {message}",
            style="{",
        )
    )
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False


def log_operation(operation, *, user=None, **attrs):
    """Log a business operation at INFO level.

    ``operation`` is a stable dotted name such as ``invoice.confirm``.
    ``attrs`` are extra context fields (object ids, outcomes, etc.).
    Sensitive fields should not be passed.
    """
    parts = [f"operation={operation}"]
    if user is not None:
        parts.append(f"user={user}")
    for key, value in attrs.items():
        parts.append(f"{key}={value}")
    logger.info(" ".join(parts))
