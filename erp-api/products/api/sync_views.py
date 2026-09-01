"""Pure synchronous DRF implementation used only by the benchmark.

This intentionally mirrors products.api.views.ProductViewSet one-for-one,
but uses DRF's synchronous ModelViewSet and synchronous Django ORM. It is
selected only when BENCH_API_STACK=sync; production routing is unchanged.
"""

from django.db.models import OuterRef, Subquery, Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import filters, viewsets

from common.pagination import StandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission

from products.api.serializers import CartonPricingSerializer, ProductSerializer
from products.models import CartonPricing, Product


class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)
    pagination_class = StandardPagination

    filter_backends = (filters.SearchFilter, filters.OrderingFilter)
    search_fields = ("name",)
    ordering_fields = (
        "name",
        "purchase_price",
        "selling_price",
        "created_at",
        "updated_at",
    )
    ordering = ("name", "pk")

    def get_queryset(self):
        sold_subquery = self._confirmed_invoice_item_qty()
        stock_subquery = self._total_stock_subquery()

        return Product.objects.annotate(
            _total_stock=Coalesce(Subquery(stock_subquery), Value(0)),
            _sold_quantity=Coalesce(Subquery(sold_subquery), Value(0)),
        )

    @staticmethod
    def _total_stock_subquery():
        from inventory.models import StockBalance

        return (
            StockBalance.objects.filter(product_id=OuterRef("pk"))
            .values("product_id")
            .annotate(total=Sum("quantity"))
            .values("total")
        )

    @staticmethod
    def _confirmed_invoice_item_qty():
        from invoices.models import Invoice, InvoiceItem

        return (
            InvoiceItem.objects.filter(
                product_id=OuterRef("pk"),
                invoice__status__in=(
                    Invoice.Status.CONFIRMED,
                    Invoice.Status.PAID,
                ),
            )
            .values("product_id")
            .annotate(total=Sum("quantity"))
            .values("total")
        )


class CartonPricingViewSet(viewsets.ModelViewSet):
    serializer_class = CartonPricingSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)
    pagination_class = StandardPagination

    filter_backends = (filters.SearchFilter, filters.OrderingFilter)
    search_fields = ("name",)
    ordering_fields = (
        "name",
        "units_per_carton",
        "carton_price",
        "created_at",
        "updated_at",
    )
    ordering = ("name", "pk")

    def get_queryset(self):
        return CartonPricing.objects.all()
