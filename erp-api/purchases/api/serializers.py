from rest_framework import serializers

from purchases.models import Purchase, PurchaseItem


class PurchaseItemSerializer(serializers.ModelSerializer):
    total_amount = serializers.DecimalField(
        max_digits=14,
        decimal_places=2,
        read_only=True,
    )

    class Meta:
        model = PurchaseItem
        fields = (
            "id",
            "product",
            "quantity",
            "unit_purchase_price",
            "total_amount",
        )


class PurchaseSerializer(serializers.ModelSerializer):
    items = PurchaseItemSerializer(many=True)

    class Meta:
        model = Purchase
        fields = (
            "id",
            "supplier",
            "status",
            "reference",
            "created_by",
            "created_at",
            "updated_at",
            "total_amount",
            "items",
        )
        read_only_fields = (
            "id",
            "status",
            "created_by",
            "created_at",
            "updated_at",
            "total_amount",
        )

    def create(self, validated_data):
        items_data = validated_data.pop("items")
        purchase = Purchase.objects.create(
            created_by=self.context["request"].user,
            **validated_data,
        )

        PurchaseItem.objects.bulk_create(
            PurchaseItem(
                purchase=purchase,
                **item_data,
            )
            for item_data in items_data
        )

        return purchase


    def update(self, instance, validated_data):
        if instance.status != Purchase.Status.DRAFT:
            raise serializers.ValidationError(
                "Only draft purchases can be modified."
            )
    
        items_data = validated_data.pop("items", None)
    
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
    
        instance.save()
    
        if items_data is not None:
            instance.items.all().delete()
    
            PurchaseItem.objects.bulk_create(
                PurchaseItem(
                    purchase=instance,
                    **item_data,
                )
                for item_data in items_data
            )
    
        return instance