from django.db import transaction
from rest_framework import serializers

from ..models import Coupon, Customer, Invoice, InvoiceItem, Payment, Product


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = "__all__"
        read_only_fields = ("id", "created_at", "updated_at")


class ProductSerializer(serializers.ModelSerializer):
    sold_quantity = serializers.IntegerField(read_only=True)
    remaining_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = Product
        fields = (
            "id",
            "name",
            "price",
            "stock_quantity",
            "sold_quantity",
            "remaining_quantity",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at", "sold_quantity", "remaining_quantity")


class CouponSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coupon
        fields = "__all__"
        read_only_fields = ("id", "created_at", "updated_at")


class InvoiceItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    line_total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = InvoiceItem
        fields = ("id", "product", "product_name", "quantity", "unit_price", "line_total")
        read_only_fields = ("id", "product_name", "line_total")


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = "__all__"
        read_only_fields = ("id", "created_at", "confirmed_at")


class InvoiceSerializer(serializers.ModelSerializer):
    items = InvoiceItemSerializer(many=True)
    subtotal = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    sold_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = Invoice
        fields = ("id", "customer", "created_by", "coupon", "coupon_discount", "subtotal", "total", "sold_quantity", "items", "created_at", "updated_at")
        read_only_fields = ("id", "created_by", "subtotal", "total", "sold_quantity", "created_at", "updated_at")

    def create(self, validated_data):
        items = validated_data.pop("items")
        request = self.context["request"]
        with transaction.atomic():
            invoice = Invoice.objects.create(created_by=request.user, **validated_data)
            for item in items:
                product = item["product"]
                InvoiceItem.objects.create(invoice=invoice, unit_price=product.price, **item)
        return invoice


class InvoiceSummarySerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    subtotal = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    sold_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = Invoice
        fields = ("id", "customer", "customer_name", "subtotal", "coupon_discount", "total", "sold_quantity", "created_at", "updated_at")
