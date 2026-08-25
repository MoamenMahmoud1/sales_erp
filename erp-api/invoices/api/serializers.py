from django.db import transaction
from rest_framework import serializers

from common.money import quantize_money
from invoices.models import Invoice, InvoiceItem


class InvoiceItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    line_total = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )

    class Meta:
        model = InvoiceItem
        fields = (
            "id",
            "product",
            "product_name",
            "quantity",
            "unit_price",
            "line_total",
        )
        read_only_fields = (
            "id",
            "product_name",
            "unit_price",
            "line_total",
        )

    def validate_quantity(self, value):
        if value < 1:
            raise serializers.ValidationError(
                "Quantity must be at least 1."
            )
        return value


class InvoiceSerializer(serializers.ModelSerializer):
    items = InvoiceItemSerializer(many=True)
    subtotal = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    total = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    sold_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = Invoice
        fields = (
            "id",
            "customer",
            "created_by",
            "coupon",
            "coupon_discount",
            "subtotal",
            "total",
            "sold_quantity",
            "items",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "created_by",
            "coupon_discount",  # authoritative → computed by the backend,
            # never trusted from the client.
            "subtotal",
            "total",
            "sold_quantity",
            "created_at",
            "updated_at",
        )

    def create(self, validated_data):
        items = validated_data.pop("items")
        request = self.context["request"]
        with transaction.atomic():
            invoice = Invoice.objects.create(
                created_by=request.user, **validated_data
            )
            for item in items:
                product = item["product"]
                # Snapshot the unit price from the product at invoice creation
                # time so that later Product.price changes never alter the
                # historical financial value of this invoice. The client can
                # never supply unit_price (read-only field).
                InvoiceItem.objects.create(
                    invoice=invoice,
                    product=product,
                    quantity=item["quantity"],
                    unit_price=quantize_money(product.price),
                )
        return invoice


class InvoiceSummarySerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    subtotal = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    total = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    sold_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = Invoice
        fields = (
            "id",
            "customer",
            "customer_name",
            "subtotal",
            "coupon_discount",
            "total",
            "sold_quantity",
            "created_at",
            "updated_at",
        )