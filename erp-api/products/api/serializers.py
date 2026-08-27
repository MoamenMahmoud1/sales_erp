from adrf import serializers

from products.models import CartonPricing, Product


class ProductSerializer(serializers.ModelSerializer):
    sold_quantity = serializers.IntegerField(
        read_only=True,
    )

    remaining_quantity = serializers.IntegerField(
        read_only=True,
    )

    class Meta:
        model = Product

        fields = (
            "id",
            "name",
            "purchase_price",
            "selling_price",
            "stock_quantity",
            "sold_quantity",
            "remaining_quantity",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "id",
            "stock_quantity",
            "sold_quantity",
            "remaining_quantity",
            "created_at",
            "updated_at",
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