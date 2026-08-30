from adrf import viewsets
from django.db.models import Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import filters

from common.pagination import StandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission

from products.api.serializers import (
    CartonPricingSerializer,
    ProductSerializer,
)
from products.models import CartonPricing, Product

class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = (
        ReadAuthenticatedWriteStaffPermission,
    )
    pagination_class = StandardPagination

    filter_backends = (
        filters.SearchFilter,
        filters.OrderingFilter,
    )

    search_fields = (
        "name",
    )

    ordering_fields = (
        "name",
        "purchase_price",
        "selling_price",
        "stock_quantity",
        "created_at",
        "updated_at",
    )

    ordering = (
        "name",
        "pk",
    )

    def get_queryset(self):
        return Product.objects.annotate(
            _sold_quantity=Coalesce(
                Sum("invoice_items__quantity"),
                Value(0),
            ),
        )


class CartonPricingViewSet(viewsets.ModelViewSet):
    serializer_class = CartonPricingSerializer
    permission_classes = (
        ReadAuthenticatedWriteStaffPermission,
    )
    pagination_class = StandardPagination

    filter_backends = (
        filters.SearchFilter,
        filters.OrderingFilter,
    )

    search_fields = (
        "name",
    )

    ordering_fields = (
        "name",
        "units_per_carton",
        "carton_price",
        "created_at",
        "updated_at",
    )

    ordering = (
        "name",
        "pk",
    )

    def get_queryset(self):
        return CartonPricing.objects.all()
