"""
Small, consistent domain-exception hierarchy.

These are ordinary Python exceptions raised by business logic. They are kept
minimal and are NOT wrapped in a framework. Later phases (invoice lifecycle,
payment collection) may raise them so the API can translate them into
consistent error responses.

We intentionally add only exceptions that are meaningful now or in the near
term. No monolithic exception tree.
"""


class DomainError(Exception):
    """Base class for recoverable business-rule violations."""


class InvalidBusinessOperation(DomainError):
    """Raised when a requested business operation is invalid for the object."""


class InvalidMoney(DomainError):
    """Raised when a monetary value breaks the money convention."""


class InvalidDiscount(DomainError):
    """Raised when a discount is invalid (e.g. exceeds the subtotal)."""


# NOTE: InvalidStateTransition is intentionally omitted until the invoice
# state machine exists (Phase 4), per the "no premature abstractions" rule.