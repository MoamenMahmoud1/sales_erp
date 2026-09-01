"""Atomic purchase create/update service."""

from asgiref.sync import sync_to_async
from django.db import transaction

from purchases.models import Purchase, PurchaseItem


class PurchaseWriteService:
    """Own purchase persistence and its sync/async execution boundary."""

    @staticmethod
    @transaction.atomic
    def create(*, validated_data, user):
        data = validated_data.copy()
        items_data = data.pop("items")
        purchase = Purchase.objects.create(created_by=user, **data)
        PurchaseItem.objects.bulk_create(
            [PurchaseItem(purchase=purchase, **item_data) for item_data in items_data]
        )
        return purchase

    @staticmethod
    async def acreate(*, validated_data, user):
        return await sync_to_async(
            PurchaseWriteService.create,
            thread_sensitive=True,
        )(validated_data=validated_data, user=user)

    @staticmethod
    @transaction.atomic
    def update(*, instance, validated_data):
        if instance.status != Purchase.Status.DRAFT:
            raise ValueError("Only draft purchases can be edited.")

        data = validated_data.copy()
        items_data = data.pop("items", None)

        for attr, value in data.items():
            setattr(instance, attr, value)
        instance.save()

        if items_data is not None:
            instance.items.all().delete()
            PurchaseItem.objects.bulk_create(
                [PurchaseItem(purchase=instance, **item_data) for item_data in items_data]
            )

        return instance

    @staticmethod
    async def aupdate(*, instance, validated_data):
        return await sync_to_async(
            PurchaseWriteService.update,
            thread_sensitive=True,
        )(instance=instance, validated_data=validated_data)
