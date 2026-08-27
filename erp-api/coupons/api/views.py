from adrf import viewsets
from rest_framework import filters

from common.permissions import ReadAuthenticatedWriteStaffPermission

from coupons.api.serializers import CouponSerializer
from coupons.models import Coupon


class CouponViewSet(viewsets.ModelViewSet):
    permission_classes = (
        ReadAuthenticatedWriteStaffPermission,
    )

    serializer_class = CouponSerializer

    filter_backends = (
        filters.SearchFilter,
        filters.OrderingFilter,
    )

    search_fields = (
        "code",
    )

    ordering_fields = (
        "code",
        "discount_type",
        "discount_value",
        "minimum_invoice_amount",
        "is_active",
        "valid_from",
        "valid_until",
        "created_at",
        "updated_at",
    )

    ordering = (
        "code",
        "pk",
    )

    def get_queryset(self):
        return Coupon.objects.all()