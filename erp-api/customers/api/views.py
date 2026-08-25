from rest_framework.viewsets import ModelViewSet

from common.permissions import ReadAuthenticatedWriteStaffPermission
from customers.api.serializers import CustomerSerializer
from customers.models import Customer


class CustomerViewSet(ModelViewSet):
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)