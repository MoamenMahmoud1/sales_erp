from asgiref.sync import sync_to_async
from django.db import transaction

from inventory.models import StockBalance


class StockBalanceService:
    """Atomic stock mutations with transaction-safe internal primitives.

    ``increase()``/``decrease()`` remain independently atomic for standalone
    callers. Domain workflows that already hold an outer transaction should
    use the ``*_in_transaction()`` variants to avoid creating a SAVEPOINT for
    every stock row touched inside a larger transaction.
    """

    @staticmethod
    def _increase(*, location, product, quantity):
        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero.")

        balance, _ = (
            StockBalance.objects
            .select_for_update()
            .get_or_create(
                location=location,
                product=product,
                defaults={"quantity": 0},
            )
        )

        balance.quantity += quantity
        balance.save(update_fields=["quantity", "updated_at"])
        return balance

    @staticmethod
    def _decrease(*, location, product, quantity):
        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero.")

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

    @staticmethod
    @transaction.atomic
    def increase(*, location, product, quantity):
        return StockBalanceService._increase(
            location=location,
            product=product,
            quantity=quantity,
        )

    @staticmethod
    def increase_in_transaction(*, location, product, quantity):
        """Mutate stock inside an already-open transaction without a savepoint."""
        return StockBalanceService._increase(
            location=location,
            product=product,
            quantity=quantity,
        )

    @staticmethod
    async def aincrease(*, location, product, quantity):
        return await sync_to_async(
            StockBalanceService.increase,
            thread_sensitive=True,
        )(location=location, product=product, quantity=quantity)

    @staticmethod
    @transaction.atomic
    def decrease(*, location, product, quantity):
        return StockBalanceService._decrease(
            location=location,
            product=product,
            quantity=quantity,
        )

    @staticmethod
    def decrease_in_transaction(*, location, product, quantity):
        """Mutate stock inside an already-open transaction without a savepoint."""
        return StockBalanceService._decrease(
            location=location,
            product=product,
            quantity=quantity,
        )

    @staticmethod
    async def adecrease(*, location, product, quantity):
        return await sync_to_async(
            StockBalanceService.decrease,
            thread_sensitive=True,
        )(location=location, product=product, quantity=quantity)
