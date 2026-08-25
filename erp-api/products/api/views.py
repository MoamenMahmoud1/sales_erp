from django.db.models import Sum
from rest_framework.viewsets import ModelViewSet

from common.permissions import ReadAuthenticatedWriteStaffPermission
from products.api.serializers import (
    CartonPricingSerializer,
    ProductSerializer,
)
from products.models import CartonPricing, Product


class ProductViewSet(ModelViewSet):
    queryset = (
        Product.objects.annotate(_sold_quantity=Sum("invoice_items__quantity"))
        .order_by("name", "pk")
    )
    serializer_class = ProductSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)


class CartonPricingViewSet(ModelViewSet):
    queryset = CartonPricing.objects.all()
    serializer_class = CartonPricingSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)