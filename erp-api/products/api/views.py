from adrf import viewsets
from django.db.models import OuterRef, Subquery, Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import filters
from rest_framework.response import Response

from common.pagination import AsyncStandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission
from common.services.async_db_gate import db_slot, consume_wait
from common.services.async_serializer import AsyncSerializerService

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
    pagination_class = AsyncStandardPagination

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
        "created_at",
        "updated_at",
    )

    ordering = (
        "name",
        "pk",
    )

    async def afilter_queryset(self, queryset):
        """Apply lazy QuerySet filters without a sync-to-async thread hop."""
        for backend_class in self.filter_backends:
            queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    async def alist(self, request, *args, **kwargs):
        """List products with bounded DB concurrency and one serializer hop."""
        queryset = await self.afilter_queryset(self.get_queryset())

        # Gate only the DB-bound section. As soon as both COUNT and page
        # evaluation finish, the slot is released for the next request while
        # response serialization can proceed independently.
        async with db_slot():
            page = await self.apaginate_queryset(queryset)
        request._benchmark_db_gate_wait_ms = consume_wait() * 1000

        request._benchmark_serializer_path = "batched_sync_representation"
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            data = await AsyncSerializerService.adata(serializer)
            return await self.get_apaginated_response(data)

        serializer = self.get_serializer(queryset, many=True)
        data = await AsyncSerializerService.adata(serializer)
        return Response(data, status=200)

    def get_queryset(self):
        # Keep stock and sold totals in independent correlated subqueries so
        # their joins cannot multiply each other.
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
    permission_classes = (
        ReadAuthenticatedWriteStaffPermission,
    )
    pagination_class = AsyncStandardPagination

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

    async def afilter_queryset(self, queryset):
        for backend_class in self.filter_backends:
            queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    def get_queryset(self):
        return CartonPricing.objects.all()
