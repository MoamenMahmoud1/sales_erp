"""Locked invoice lifecycle transitions."""

from asgiref.sync import sync_to_async
from django.db import transaction

from common.exceptions import (
    InsufficientStock,
    InvalidBusinessOperation,
    InvalidStateTransition,
)
from common.observability import log_operation
from inventory.models import StockLocation, StockMovement, StockMovementItem
from inventory.services.stock_balance import StockBalanceService
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


def sales_source_location_sync(user):
    """Return the active SALES_VEHICLE location bound to ``user``.

    The inventory business model ties a salesperson to a sales vehicle
    (``StockLocation.employee``). A confirmed invoice reduces stock from the
    invoice creator's vehicle — the location the sale physically left from.
    """
    return (
        StockLocation.objects.filter(
            employee=user,
            location_type=StockLocation.LocationType.SALES_VEHICLE,
            is_active=True,
        )
        .select_for_update()
        .first()
    )


def _record_sale_movement_sync(invoice, source_location):
    """Decrease stock and create the SALE ledger rows inside the open transaction."""
    movement = StockMovement.objects.create(
        movement_type=StockMovement.MovementType.SALE,
        source_location=source_location,
        created_by=invoice.created_by,
        reference=f"Invoice #{invoice.pk}",
    )

    for item in invoice.items.select_related("product").all():
        try:
            StockBalanceService.decrease(
                location=source_location,
                product=item.product,
                quantity=item.quantity,
            )
        except ValueError as exc:
            raise InsufficientStock(
                f"Insufficient stock for {item.product.name} in "
                f"{source_location.name}."
            ) from exc

        StockMovementItem.objects.create(
            movement=movement,
            product=item.product,
            quantity=item.quantity,
        )

    return movement


def _confirm_invoice_sync(invoice_id):
    """Keep the transaction, row locks, validation, stock and status change atomic."""
    with transaction.atomic():
        invoice = load_invoice_for_update_sync(invoice_id)
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
            items=len(list(invoice.items.all())),
        )
        return invoice


def _cancel_invoice_sync(invoice_id):
    """Cancel an invoice, reversing stock if it was confirmed.

    DRAFT -> CANCELLED: no inventory impact.
    CONFIRMED -> CANCELLED: creates a compensating SALEABLE_RETURN movement
    that restores stock to the sales location.  The original SALE movement
    remains immutable.
    """
    with transaction.atomic():
        invoice = load_invoice_for_update_sync(invoice_id)
        if invoice.status not in (Invoice.Status.DRAFT, Invoice.Status.CONFIRMED):
            raise InvalidStateTransition(
                f"Cannot cancel an invoice in state {invoice.status}."
            )

        if invoice.status == Invoice.Status.CONFIRMED:
            _reverse_sale_movement_sync(invoice)

        invoice.status = Invoice.Status.CANCELLED
        invoice.save(update_fields=("status", "updated_at"))
        log_operation(
            "invoice.cancel",
            user=invoice.created_by_id,
            invoice=invoice.pk,
            was_confirmed=invoice.status == Invoice.Status.CANCELLED,
        )
        return invoice


def _find_original_sale_location_sync(invoice):
    """Return the source location of the original SALE movement.

    The original SALE movement is authoritative for where stock was removed.
    We must NOT use the employee's current location — they may have moved
    to a different sales vehicle since the sale.
    """
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
    """Create a compensating SALEABLE_RETURN movement to restore stock.

    The original SALE movement is never edited — it remains an immutable
    ledger entry.  This function creates a separate reversal movement that
    increases the stock balance back to the ORIGINAL sales location (from
    the SALE movement), not the employee's current location.
    """
    source_location = _find_original_sale_location_sync(invoice)

    movement = StockMovement.objects.create(
        movement_type=StockMovement.MovementType.SALEABLE_RETURN,
        destination_location=source_location,
        created_by=invoice.created_by,
        reference=f"Cancel Invoice #{invoice.pk}",
    )

    for item in invoice.items.select_related("product").all():
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


class ConfirmInvoice:
    """Transition DRAFT to CONFIRMED atomically, including the sale inventory move."""

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
