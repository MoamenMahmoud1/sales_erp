from adrf import serializers

from purchases.models import Purchase, PurchaseItem


class PurchaseItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)

    class Meta:
        model = PurchaseItem
        fields = (
            "id", "product", "product_name", "quantity",
            "unit_purchase_price", "total_amount",
        )
        read_only_fields = ("id", "product_name", "total_amount")


class PurchaseListSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source="supplier.name", read_only=True)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = Purchase
        fields = (
            "id", "supplier", "supplier_name", "status", "reference",
            "created_at", "total_amount",
        )
        read_only_fields = fields


class PurchaseSerializer(serializers.ModelSerializer):
    items = PurchaseItemSerializer(many=True)
    supplier_name = serializers.CharField(source="supplier.name", read_only=True)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = Purchase
        fields = (
            "id", "supplier", "supplier_name", "status", "reference",
            "created_by", "created_at", "updated_at", "total_amount", "items",
        )
        read_only_fields = (
            "id", "status", "created_by", "created_at", "updated_at", "total_amount",
        )

    def validate_supplier(self, supplier):
        if not supplier.is_active:
            raise serializers.ValidationError("Supplier is inactive.")
        return supplier

    def validate_items(self, items):
        if not items:
            raise serializers.ValidationError("Purchase must contain at least one item.")

        product_ids = [item["product"].pk for item in items]
        if len(product_ids) != len(set(product_ids)):
            raise serializers.ValidationError("A product cannot appear more than once.")
        return items
