from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import Q


class Product(models.Model):
    name = models.CharField(max_length=200)
    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    stock_quantity = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)
        indexes = [
            models.Index(fields=("name",), name="products_product_name_idx")
        ]
        constraints = [
            models.CheckConstraint(
                condition=Q(price__gte=Decimal("0")),
                name="product_price_non_negative",
            ),
        ]

    @property
    def sold_quantity(self):
        if hasattr(self, "_sold_quantity"):
            return self._sold_quantity or 0
        return (
            self.invoice_items.aggregate(total=models.Sum("quantity"))["total"]
            or 0
        )

    @property
    def remaining_quantity(self):
        return max(0, self.stock_quantity - self.sold_quantity)

    def __str__(self):
        return self.name


class CartonPricing(models.Model):
    """Pricing model for selling a product in carton (pack) units.

    This represents carton / pack pricing (units per carton + carton price).
    Originally this concept was incorrectly named ``Coupon`` in a monolith.
    It is NOT a discount coupon — that now lives in the ``coupons`` app.
    """

    name = models.CharField(max_length=200)
    units_per_carton = models.PositiveIntegerField(
        validators=[MinValueValidator(1)]
    )
    carton_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0"))],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)
        verbose_name = "Carton pricing"
        verbose_name_plural = "Carton pricings"
        constraints = [
            models.CheckConstraint(
                condition=Q(carton_price__gte=Decimal("0")),
                name="cartonpricing_carton_price_non_negative",
            ),
        ]

    def __str__(self):
        return self.name