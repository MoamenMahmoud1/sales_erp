"""
Focused application/use-case services for the invoice domain.

These implement meaningful business operations: confirming, cancelling, and
applying coupons to invoices. They enforce the explicit lifecycle, guard the
financial snapshot, and run atomically.

Django-native persistence (no repositories/interfaces).
"""

from django.db import transaction
from django.utils import timezone

from common.exceptions import (
    CouponInvalid,
    InvalidBusinessOperation,
    InvalidStateTransition,
)
from coupons.models import Coupon
from invoices.calculator import InvoiceCalculator
from invoices.models import Invoice

_calculator = InvoiceCalculator()


class InvoiceNotFound(InvalidBusinessOperation):
    pass


def _load_for_update(invoice_id):
    try:
        return (
            Invoice.objects.select_for_update()
            .select_related("customer", "coupon", "created_by")
            .prefetch_related("items__product")
            .get(pk=invoice_id)
        )
    except Invoice.DoesNotExist as exc:
        raise InvoiceNotFound("Invoice not found.") from exc


class ConfirmInvoice:
    """Transition DRAFT -> CONFIRMED."""

    def __call__(self, invoice_id):
        with transaction.atomic():
            invoice = _load_for_update(invoice_id)
            if invoice.status != Invoice.Status.DRAFT:
                raise InvalidStateTransition(
                    "Only a draft invoice can be confirmed."
                )
            invoice.status = Invoice.Status.CONFIRMED
            invoice.save(update_fields=("status", "updated_at"))
        return invoice


class CancelInvoice:
    """Transition DRAFT -> CANCELLED or CONFIRMED -> CANCELLED."""

    def __call__(self, invoice_id):
        with transaction.atomic():
            invoice = _load_for_update(invoice_id)
            if invoice.status in (Invoice.Status.DRAFT, Invoice.Status.CONFIRMED):
                invoice.status = Invoice.Status.CANCELLED
                invoice.save(update_fields=("status", "updated_at"))
                return invoice
            raise InvalidStateTransition(
                f"Cannot cancel an invoice in state {invoice.status}."
            )


class ApplyCoupon:
    """Apply a coupon to a DRAFT invoice and persist the discount snapshot."""

    def __call__(self, *, invoice_id, code):
        with transaction.atomic():
            invoice = _load_for_update(invoice_id)
            if invoice.status != Invoice.Status.DRAFT:
                raise InvalidStateTransition(
                    "A coupon can only be applied to a draft invoice."
                )

            try:
                coupon = Coupon.objects.get(code=code)
            except Coupon.DoesNotExist as exc:
                raise CouponInvalid("Coupon not found.") from exc

            self._validate_coupon(coupon, invoice)

            subtotal = _calculator.subtotal(invoice)
            discount = _calculator.coupon_discount_value(coupon, subtotal)

            invoice.coupon = coupon
            invoice.coupon_discount = discount
            invoice.save(update_fields=("coupon", "coupon_discount", "updated_at"))
        return invoice

    def _validate_coupon(self, coupon, invoice):
        if not coupon.is_active:
            raise CouponInvalid("Coupon is not active.")

        now = timezone.now()
        if coupon.valid_from and now < coupon.valid_from:
            raise CouponInvalid("Coupon is not yet valid.")
        if coupon.valid_until and now > coupon.valid_until:
            raise CouponInvalid("Coupon has expired.")

        if coupon.minimum_invoice_amount:
            subtotal = _calculator.subtotal(invoice)
            if subtotal < coupon.minimum_invoice_amount:
                raise CouponInvalid(
                    "The invoice does not meet the coupon's minimum amount."
                )