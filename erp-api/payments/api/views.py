from rest_framework.viewsets import ModelViewSet

from common.permissions import ReadAuthenticatedWriteStaffPermission
from payments.api.serializers import PaymentSerializer
from payments.models import Payment


class PaymentViewSet(ModelViewSet):
    queryset = Payment.objects.select_related("invoice", "invoice__customer")
    serializer_class = PaymentSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)