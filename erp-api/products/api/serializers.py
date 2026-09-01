from adrf import serializers

from products.models import CartonPricing, Product


class ProductSerializer(serializers.ModelSerializer):
    sold_quantity = serializers.IntegerField(
        read_only=True,
    )

    total_stock = serializers.IntegerField(
        read_only=True,
    )

    stock_quantity = serializers.IntegerField(
        read_only=True,
        source="total_stock",
        help_text=(
            "DEPRECATED derived alias of total_stock. Computed from "
            "inventory.StockBalance — NOT an independently stored value."
        ),
    )

    class Meta:
        model = Product
        fields = (
            "id",
            "name",
            "purchase_price",
            "selling_price",
            "total_stock",
            "stock_quantity",
            "sold_quantity",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "created_at",
            "updated_at",
            "total_stock",
            "stock_quantity",
            "sold_quantity",
        )


class CartonPricingSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartonPricing
        fields = (
            "id",
            "name",
            "units_per_carton",
            "carton_price",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "created_at",
            "updated_at",
        )
