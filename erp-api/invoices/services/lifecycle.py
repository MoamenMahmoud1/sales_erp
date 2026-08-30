"""Locked invoice lifecycle transitions."""

from asgiref.sync import sync_to_async
from django.db import transaction

from common.exceptions import InvalidBusinessOperation, InvalidStateTransition
from invoices.models import Invoice


class InvoiceNotFound(InvalidBusinessOperation):
    """Raised when a requested invoice does not exist."""


def load_invoice_for_update_sync(invoice_id):
    """Load a lifecycle target; callers must hold ``transaction.atomic()``."""
    try:
        return (
            Invoice.objects.select_for_update(of=("self",))
            .select_related("customer", "coupon", "created_by")
            .prefetch_related("items__product")
            .get(pk=invoice_id)
        )
    except Invoice.DoesNotExist as exc:
        raise InvoiceNotFound("Invoice not found.") from exc


def _confirm_invoice_sync(invoice_id):
    """Keep the transaction and lock together without an await."""
    with transaction.atomic():
        invoice = load_invoice_for_update_sync(invoice_id)
        if invoice.status != Invoice.Status.DRAFT:
            raise InvalidStateTransition("Only a draft invoice can be confirmed.")
        invoice.status = Invoice.Status.CONFIRMED
        invoice.save(update_fields=("status", "updated_at"))
        return invoice


def _cancel_invoice_sync(invoice_id):
    """Keep the transaction and lock together without an await."""
    with transaction.atomic():
        invoice = load_invoice_for_update_sync(invoice_id)
        if invoice.status not in (Invoice.Status.DRAFT, Invoice.Status.CONFIRMED):
            raise InvalidStateTransition(
                f"Cannot cancel an invoice in state {invoice.status}."
            )
        invoice.status = Invoice.Status.CANCELLED
        invoice.save(update_fields=("status", "updated_at"))
        return invoice


class ConfirmInvoice:
    """Transition DRAFT to CONFIRMED atomically."""

    async def __call__(self, invoice_id):
        return await sync_to_async(
            _confirm_invoice_sync,
            thread_sensitive=True,
        )(invoice_id)


class CancelInvoice:
    """Transition DRAFT or CONFIRMED to CANCELLED atomically."""

    async def __call__(self, invoice_id):
        return await sync_to_async(
            _cancel_invoice_sync,
            thread_sensitive=True,
        )(invoice_id)
