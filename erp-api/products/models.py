from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import Q, Sum


# Business statuses that represent a real, completed SALE. Draft and cancelled
# invoices are NOT sales and must never contribute to product sold quantities.
_INVOICE_SALE_STATUSES = ("confirmed", "paid")


class Product(models.Model):
    name = models.CharField(
        max_length=200,
    )

    purchase_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0")),
        ],
    )

    selling_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0")),
        ],
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ("name",)

        indexes = [
            models.Index(
                fields=("name",),
                name="products_product_name_idx",
            ),
        ]

        constraints = [
            models.CheckConstraint(
                condition=Q(
                    purchase_price__gte=Decimal("0"),
                ),
                name="product_purchase_price_non_negative",
            ),
            models.CheckConstraint(
                condition=Q(
                    selling_price__gte=Decimal("0"),
                ),
                name="product_selling_price_non_negative",
            ),
        ]

    @property
    def total_stock(self):
        """Aggregated current stock across every StockLocation.

        ``inventory.StockBalance`` is the SINGLE authoritative current-stock
        state — this is computed by aggregating balances, never a stored field.
        """
        annotated = getattr(self, "_total_stock", None)
        if annotated is not None:
            return annotated
        return (
            self.stock_balances.aggregate(total=Sum("quantity"))["total"] or 0
        )

    @property
    def stock_quantity(self):
        """DEPRECATED derived alias of ``total_stock``.

        Retained only so existing API consumers keep receiving a ``stock_quantity``
        key. It is NOT authoritative — it is computed from StockBalance and must
        never be written directly.
        """
        return self.total_stock

    @property
    def sold_quantity(self):
        """Quantity sold on confirmed/paid invoices only.

        Draft and cancelled invoices are NOT sales and do not count. Prefer the
        queryset annotation ``_sold_quantity`` for list/detail endpoints to avoid
        per-row queries.
        """
        if hasattr(self, "_sold_quantity"):
            return self._sold_quantity or 0

        return (
            self.invoice_items.filter(
                invoice__status__in=_INVOICE_SALE_STATUSES,
            ).aggregate(total=Sum("quantity"))["total"]
            or 0
        )

    def __str__(self):
        return self.name


class CartonPricing(models.Model):
    """
    Pricing model for selling a product in carton/pack units.

    This is not a discount coupon.
    Discount coupons belong to the coupons app.
    """

    name = models.CharField(
        max_length=200,
    )

    units_per_carton = models.PositiveIntegerField(
        validators=[
            MinValueValidator(1),
        ],
    )

    carton_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0")),
        ],
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ("name",)

        verbose_name = "Carton pricing"
        verbose_name_plural = "Carton pricings"

        constraints = [
            models.CheckConstraint(
                condition=Q(
                    carton_price__gte=Decimal("0"),
                ),
                name="cartonpricing_carton_price_non_negative",
            ),
        ]

    def __str__(self):
        return self.name