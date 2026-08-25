from decimal import Decimal

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models


class Customer(models.Model):
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=40, blank=True)
    address = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)
        indexes = [models.Index(fields=("name",))]

    def __str__(self):
        return self.name


class Product(models.Model):
    name = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    stock_quantity = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)
        indexes = [models.Index(fields=("name",))]

    @property
    def sold_quantity(self):
        if hasattr(self, "_sold_quantity"):
            return self._sold_quantity or 0
        return self.invoice_items.aggregate(total=models.Sum("quantity"))["total"] or 0

    @property
    def remaining_quantity(self):
        return max(0, self.stock_quantity - self.sold_quantity)

    def __str__(self):
        return self.name


class Coupon(models.Model):
    name = models.CharField(max_length=200)
    units_per_carton = models.PositiveIntegerField(validators=[MinValueValidator(1)])
    carton_price = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)

    def __str__(self):
        return self.name


class Invoice(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="invoices")
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="created_invoices")
    coupon = models.ForeignKey(Coupon, null=True, blank=True, on_delete=models.PROTECT)
    coupon_discount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0"))
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("customer", "created_at"))]

    @property
    def subtotal(self):
        return sum((item.line_total for item in self.items.all()), Decimal("0"))

    @property
    def total(self):
        return max(Decimal("0"), self.subtotal - self.coupon_discount)

    @property
    def sold_quantity(self):
        return sum(item.quantity for item in self.items.all())


class InvoiceItem(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="invoice_items")
    quantity = models.PositiveIntegerField(validators=[MinValueValidator(1)])
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        constraints = [models.UniqueConstraint(fields=("invoice", "product"), name="sales_unique_invoice_product")]

    @property
    def line_total(self):
        return self.unit_price * self.quantity


class Payment(models.Model):
    class Method(models.TextChoices):
        CASH = "cash", "Cash"
        TRANSFER = "transfer", "Transfer"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"

    invoice = models.ForeignKey(Invoice, on_delete=models.PROTECT, related_name="payments")
    amount = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    method = models.CharField(max_length=20, choices=Method.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    reference = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("invoice", "status"))]
