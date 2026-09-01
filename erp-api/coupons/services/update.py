"""Application service for updating coupons."""

from asgiref.sync import sync_to_async


def update_coupon_sync(instance, validated_data):
    """Apply validated fields and preserve Coupon.save() validation."""
    for attribute, value in validated_data.items():
        setattr(instance, attribute, value)
    instance.save()
    return instance


class UpdateCoupon:
    """Update a coupon from either sync or async application code."""

    def __call__(self, *, instance, validated_data):
        return update_coupon_sync(instance, validated_data)

    async def acall(self, *, instance, validated_data):
        """Async entry point; keeps the blocking save off the event loop."""
        return await sync_to_async(
            update_coupon_sync,
            thread_sensitive=True,
        )(instance, validated_data)
