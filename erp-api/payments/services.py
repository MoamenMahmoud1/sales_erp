"""
Payment collection domain.

``ProcessCollection`` is the single business operation for receiving money from
a customer and allocating it to their confirmed invoices (oldest first, cash
before transfer). The backend owns the allocation entirely — a client only
reports ``cash_amount`` and ``transfer_amount``.

The whole operation (transaction + allocations + PAID transitions) runs inside
one synchronous ``transaction.atomic()`` block that locks every candidate invoice
with ``select_for_update()``, so two concurrent collections can never allocate
the same outstanding balance twice.
"""

import hashlib
import json
from decimal import Decimal

from asgiref.sync import sync_to_async
from django.db import transaction

from common.exceptions import InvalidBusinessOperation, InvalidMoney
from common.money import quantize_money
from common.observability import log_operation
from invoices.models import Invoice
from payments.models import IdempotencyKey, PaymentAllocation, PaymentTransaction


class PaymentError(InvalidBusinessOperation):
    """Base error for payment-collection business rule violations."""


class OverpaymentError(PaymentError):
    """Raised when received money exceeds the customer's total outstanding."""


class NoConfirmableInvoicesError(PaymentError):
    """Raised when the customer has nothing confirmable to pay."""


def _paid_so_far(invoice):
    return quantize_money(
        sum(
            (allocation.total_amount for allocation in invoice.payment_allocations.all()),
            Decimal("0"),
        )
    )


def _request_signature(data) -> str:
    """Canonical SHA-256 hash of the collection request body."""
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _lookup_idempotency_sync(*, key, user, path, data):
    """Return a prior idempotency record matching key + user + path."""
    signature = _request_signature(data)
    try:
        record = IdempotencyKey.objects.get(
            key=key,
            user=user,
            path=path,
        )
    except IdempotencyKey.DoesNotExist:
        return None
    # Ensure the request body matches; mismatched bodies are a client error.
    if record.request_signature != signature:
        return "mismatch"
    return record


def _record_idempotency_sync(*, key, user, path, data, status_code, body):
    """Persist the idempotency record for a processed request."""
    signature = _request_signature(data)
    IdempotencyKey.objects.create(
        key=key,
        user=user,
        path=path,
        request_signature=signature,
        response_status=status_code,
        response_body=body,
    )


def _process_collection_sync(*, customer, cash_amount, transfer_amount):
    cash = quantize_money(cash_amount)
    transfer = quantize_money(transfer_amount)

    if cash < 0 or transfer < 0:
        raise InvalidMoney("Cash and transfer amounts must not be negative.")

    total_received = quantize_money(cash + transfer)

    # A zero-value collection is a documented no-op: nothing is persisted.
    if total_received == 0:
        return None

    with transaction.atomic():
        invoices = list(
            Invoice.objects.filter(
                customer=customer,
                status=Invoice.Status.CONFIRMED,
            )
            .select_for_update(of=("self",))
            .select_related("customer")
            .prefetch_related("items")
            .order_by("created_at", "id")
        )

        # Capture authoritative outstanding per invoice before allocating.
        info = []  # (invoice, total, paid, outstanding)
        total_outstanding = Decimal("0")
        for invoice in invoices:
            total = quantize_money(invoice.total)
            paid = _paid_so_far(invoice)
            outstanding = quantize_money(total - paid)
            if outstanding <= 0:
                continue
            info.append((invoice, total, paid, outstanding))
            total_outstanding += outstanding

        if total_outstanding == 0:
            raise NoConfirmableInvoicesError(
                "The customer has no outstanding confirmed invoices."
            )

        if total_received > total_outstanding:
            raise OverpaymentError(
                "The received amount exceeds the outstanding balance."
            )

        payment = PaymentTransaction.objects.create(
            customer=customer,
            cash_amount=cash,
            transfer_amount=transfer,
        )

        cash_remaining = cash
        transfer_remaining = transfer
        paid_map = {invoice.pk: paid for invoice, _, paid, _ in info}

        for invoice, total, _paid, outstanding in info:
            if outstanding <= 0:
                continue

            cash_use = min(cash_remaining, outstanding)
            remaining_after_cash = outstanding - cash_use
            transfer_use = min(transfer_remaining, remaining_after_cash)

            if cash_use == 0 and transfer_use == 0:
                continue

            PaymentAllocation.objects.create(
                transaction=payment,
                invoice=invoice,
                cash_amount=cash_use,
                transfer_amount=transfer_use,
            )

            paid_map[invoice.pk] += cash_use + transfer_use
            cash_remaining -= cash_use
            transfer_remaining -= transfer_use

            # CONFIRMED -> PAID when cumulative allocations reach the total.
            if paid_map[invoice.pk] >= total:
                invoice.status = Invoice.Status.PAID
                invoice.save(update_fields=("status", "updated_at"))

            if cash_remaining == 0 and transfer_remaining == 0:
                break

        log_operation(
            "payment.collection",
            user=getattr(customer, "_logged_by", None),
            customer=customer.pk,
            cash_amount=str(cash),
            transfer_amount=str(transfer),
            invoices_allocated=len(info),
        )

        return payment


class ProcessCollection:
    """Async facade over the synchronous, atomic collection operation."""

    async def __call__(self, *, customer, cash_amount, transfer_amount):
        return await sync_to_async(
            _process_collection_sync,
            thread_sensitive=True,
        )(
            customer=customer,
            cash_amount=cash_amount,
            transfer_amount=transfer_amount,
        )


__all__ = (
    "NoConfirmableInvoicesError",
    "OverpaymentError",
    "PaymentError",
    "ProcessCollection",
)