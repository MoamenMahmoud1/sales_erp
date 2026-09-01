from decimal import Decimal

from adrf import serializers as adrf_serializers
from rest_framework import serializers

from customers.models import Customer
from payments.models import PaymentAllocation, PaymentTransaction


class CollectionSerializer(adrf_serializers.Serializer):
    """Client input for a collection."""

    customer = serializers.PrimaryKeyRelatedField(queryset=Customer.objects.all())
    cash_amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=Decimal("0"),
        default=Decimal("0"),
    )
    transfer_amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=Decimal("0"),
        default=Decimal("0"),
    )

    def validate(self, attrs):
        if attrs["cash_amount"] < 0 or attrs["transfer_amount"] < 0:
            raise serializers.ValidationError(
                {"non_field_errors": ("Cash and transfer amounts must not be negative.",)}
            )
        return attrs


class PaymentAllocationSerializer(adrf_serializers.ModelSerializer):
    invoice = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = PaymentAllocation
        fields = (
            "id", "invoice", "cash_amount", "transfer_amount",
            "total_amount", "created_at",
        )
        read_only_fields = fields


class PaymentTransactionSerializer(adrf_serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    allocations = PaymentAllocationSerializer(many=True, read_only=True)

    class Meta:
        model = PaymentTransaction
        fields = (
            "id", "customer", "customer_name", "cash_amount", "transfer_amount",
            "total_amount", "allocations", "created_at",
        )
        read_only_fields = fields
