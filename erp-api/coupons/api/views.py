from rest_framework.viewsets import ModelViewSet

from common.permissions import ReadAuthenticatedWriteStaffPermission
from coupons.api.serializers import CouponSerializer
from coupons.models import Coupon


class CouponViewSet(ModelViewSet):
    queryset = Coupon.objects.all()
    serializer_class = CouponSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)