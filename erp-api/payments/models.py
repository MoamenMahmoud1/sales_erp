from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import Q

from common.money import quantize_money


class PaymentTransaction(models.Model):
    """A single collection received from a customer.

    A transaction is a (cash, transfer) pair that is then allocated across one
    or more of the customer's invoices via ``PaymentAllocation`` rows. The
    backend owns the allocation — the client only reports how much cash and
    transfer was received.
    """

    customer = models.ForeignKey(
        "customers.Customer",
        on_delete=models.PROTECT,
        related_name="payment_transactions",
    )
    cash_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    transfer_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
        constraints = [
            models.CheckConstraint(
                condition=Q(cash_amount__gte=Decimal("0")),
                name="payment_tx_cash_non_negative",
            ),
            models.CheckConstraint(
                condition=Q(transfer_amount__gte=Decimal("0")),
                name="payment_tx_transfer_non_negative",
            ),
        ]

    @property
    def total_amount(self):
        return quantize_money(self.cash_amount + self.transfer_amount)

    def __str__(self):
        return f"Tx {self.pk} ({self.customer_id})"


class PaymentAllocation(models.Model):
    """Money from one transaction allocated to one invoice.

    ``cash_amount + transfer_amount`` is the portion of the transaction that
    reduces the target invoice's outstanding balance.
    """

    transaction = models.ForeignKey(
        PaymentTransaction,
        on_delete=models.CASCADE,
        related_name="allocations",
    )
    invoice = models.ForeignKey(
        "invoices.Invoice",
        on_delete=models.PROTECT,
        related_name="payment_allocations",
    )
    cash_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    transfer_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("created_at",)
        constraints = [
            models.UniqueConstraint(
                fields=("transaction", "invoice"),
                name="payment_alloc_unique_tx_invoice",
            ),
            models.CheckConstraint(
                condition=Q(cash_amount__gte=Decimal("0")),
                name="payment_alloc_cash_non_negative",
            ),
            models.CheckConstraint(
                condition=Q(transfer_amount__gte=Decimal("0")),
                name="payment_alloc_transfer_non_negative",
            ),
        ]

    @property
    def total_amount(self):
        return quantize_money(self.cash_amount + self.transfer_amount)

    def __str__(self):
        return f"Alloc {self.pk} -> invoice {self.invoice_id}"