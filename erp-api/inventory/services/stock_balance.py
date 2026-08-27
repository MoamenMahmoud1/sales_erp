from django.db import transaction

from inventory.models import StockBalance


class StockBalanceService:
    @staticmethod
    @transaction.atomic
    def increase(*, location, product, quantity):
        balance, _ = StockBalance.objects.select_for_update().get_or_create(
            location=location,
            product=product,
            defaults={"quantity": 0},
        )

        balance.quantity += quantity
        balance.save(update_fields=["quantity", "updated_at"])

        return balance

    @staticmethod
    @transaction.atomic
    def decrease(*, location, product, quantity):
        balance = (
            StockBalance.objects
            .select_for_update()
            .filter(location=location, product=product)
            .first()
        )

        if balance is None or balance.quantity < quantity:
            raise ValueError("Insufficient stock.")

        balance.quantity -= quantity
        balance.save(update_fields=["quantity", "updated_at"])

        return balance