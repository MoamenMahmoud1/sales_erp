from django.db import transaction

from inventory.models import StockLocation, StockMovement, StockMovementItem
from inventory.services.stock_balance import StockBalanceService

from purchases.models import Purchase


class ConfirmPurchaseService:
    @staticmethod
    @transaction.atomic
    def execute(*, purchase_id):
        purchase = (
            Purchase.objects
            .select_for_update()
            .prefetch_related("items__product")
            .get(pk=purchase_id)
        )

        if purchase.status != Purchase.Status.DRAFT:
            raise ValueError("Only draft purchases can be confirmed.")

        items = list(purchase.items.all())

        if not items:
            raise ValueError("Purchase must contain at least one item.")

        warehouse = (
            StockLocation.objects
            .select_for_update()
            .get(
                location_type=StockLocation.LocationType.MAIN_WAREHOUSE,
                is_active=True,
            )
        )

        movement = StockMovement.objects.create(
            movement_type=StockMovement.MovementType.PURCHASE,
            destination_location=warehouse,
            created_by=purchase.created_by,
            reference=purchase.reference,
        )

        for item in items:
            StockBalanceService.increase(
                location=warehouse,
                product=item.product,
                quantity=item.quantity,
            )

            StockMovementItem.objects.create(
                movement=movement,
                product=item.product,
                quantity=item.quantity,
            )

        purchase.status = Purchase.Status.CONFIRMED
        purchase.save(update_fields=["status", "updated_at"])

        return purchase