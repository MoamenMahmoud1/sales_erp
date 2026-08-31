from asgiref.sync import sync_to_async
from django.db import transaction

from common.observability import log_operation
from inventory.models import StockMovement, StockMovementItem
from inventory.services import StockBalanceService, sales_source_location_sync
from invoices.exceptions import (
    InvalidBusinessOperation,
    InvalidStateTransition,
)
from invoices.models import Invoice


def _load_invoice_for_update_sync(invoice_id):
    try:
        return (
            Invoice.objects.select_for_update()
            .prefetch_related("items__product")
            .get(pk=invoice_id)
        )
    except Invoice.DoesNotExist as error:
        raise InvalidBusinessOperation("Invoice not found.") from error


def _record_sale_movement_sync(invoice, source_location):
    movement = StockMovement.objects.create(
        movement_type=StockMovement.MovementType.SALE,
        source_location=source_location,
        created_by=invoice.created_by,
        reference=f"Invoice #{invoice.pk}",
    )
    for item in invoice.items.all():
        StockBalanceService.decrease(
            location=source_location,
            product=item.product,
            quantity=item.quantity,
        )
        StockMovementItem.objects.create(
            movement=movement,
            product=item.product,
            quantity=item.quantity,
        )
    return movement


def _confirm_invoice_sync(invoice_id):
    """Keep transaction, row locks, stock and status change atomic."""
    with transaction.atomic():
        invoice = _load_invoice_for_update_sync(invoice_id)
        if invoice.status != Invoice.Status.DRAFT:
            raise InvalidStateTransition("Only a draft invoice can be confirmed.")

        source_location = sales_source_location_sync(invoice.created_by)
        if source_location is None:
            raise InvalidBusinessOperation(
                "The invoice creator has no active sales location from which "
                "to fulfill this sale."
            )

        _record_sale_movement_sync(invoice, source_location)
        invoice.status = Invoice.Status.CONFIRMED
        invoice.save(update_fields=("status", "updated_at"))
        log_operation(
            "invoice.confirm",
            user=invoice.created_by_id,
            invoice=invoice.pk,
            items=invoice.items.count(),
        )
        return invoice


def _find_original_sale_location_sync(invoice):
    """Return the source location of the immutable original SALE movement."""
    sale = (
        StockMovement.objects.filter(
            reference=f"Invoice #{invoice.pk}",
            movement_type=StockMovement.MovementType.SALE,
        )
        .select_related("source_location")
        .first()
    )
    if sale is None:
        raise InvalidBusinessOperation(
            "Cannot reverse sale: no original SALE movement found for this invoice."
        )
    return sale.source_location


def _reverse_sale_movement_sync(invoice):
    """Create a compensating return movement at the original SALE location."""
    source_location = _find_original_sale_location_sync(invoice)

    movement = StockMovement.objects.create(
        movement_type=StockMovement.MovementType.SALEABLE_RETURN,
        destination_location=source_location,
        created_by=invoice.created_by,
        reference=f"Cancel Invoice #{invoice.pk}",
    )

    for item in invoice.items.all():
        StockBalanceService.increase(
            location=source_location,
            product=item.product,
            quantity=item.quantity,
        )
        StockMovementItem.objects.create(
            movement=movement,
            product=item.product,
            quantity=item.quantity,
        )


def _cancel_invoice_sync(invoice_id):
    """Cancel an invoice and atomically reverse stock for confirmed invoices."""
    with transaction.atomic():
        invoice = _load_invoice_for_update_sync(invoice_id)
        if invoice.status not in (Invoice.Status.DRAFT, Invoice.Status.CONFIRMED):
            raise InvalidStateTransition(
                f"Cannot cancel an invoice in state {invoice.status}."
            )

        was_confirmed = invoice.status == Invoice.Status.CONFIRMED
        if was_confirmed:
            _reverse_sale_movement_sync(invoice)

        invoice.status = Invoice.Status.CANCELLED
        invoice.save(update_fields=("status", "updated_at"))
        log_operation(
            "invoice.cancel",
            user=invoice.created_by_id,
            invoice=invoice.pk,
            was_confirmed=was_confirmed,
        )
        return invoice


class ConfirmInvoice:
    async def __call__(self, *, invoice_id):
        return await sync_to_async(
            _confirm_invoice_sync,
            thread_sensitive=True,
        )(invoice_id=invoice_id)


class CancelInvoice:
    async def __call__(self, *, invoice_id):
        return await sync_to_async(
            _cancel_invoice_sync,
            thread_sensitive=True,
        )(invoice_id=invoice_id)
