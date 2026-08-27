from django.db import transaction

from inventory.models import StockLocation, StockMovement, StockMovementItem
from inventory.services.stock_balance import StockBalanceService


class TransferStockService:
    @staticmethod
    @transaction.atomic
    def execute(
        *,
        source: StockLocation,
        destination: StockLocation,
        items,
        created_by,
        reference="",
    ):
        if source.pk == destination.pk:
            raise ValueError("Source and destination must be different.")

        movement = StockMovement.objects.create(
            movement_type=StockMovement.MovementType.TRANSFER,
            source_location=source,
            destination_location=destination,
            created_by=created_by,
            reference=reference,
        )

        for item in items:
            product = item["product"]
            quantity = item["quantity"]

            StockBalanceService.decrease(
                location=source,
                product=product,
                quantity=quantity,
            )

            StockBalanceService.increase(
                location=destination,
                product=product,
                quantity=quantity,
            )

            StockMovementItem.objects.create(
                movement=movement,
                product=product,
                quantity=quantity,
            )

        return movement