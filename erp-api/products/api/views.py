from adrf import viewsets
from django.db.models import OuterRef, Subquery, Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import filters
from rest_framework.response import Response

from common.pagination import AsyncStandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission
from common.services.async_db_gate import DBAdmissionTimeout, db_slot
from common.services.async_serializer import AsyncSerializerService
from common.services.perf_timing import db_operation, view_stage

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
            name = backend_class.__name__.removesuffix("Filter").lower()
            with view_stage(f"view.filter.{name}"):
                queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    async def alist(self, request, *args, **kwargs):
        """List products with bounded DB concurrency and one serializer hop."""
        with view_stage("view.total"):
            with view_stage("view.queryset.build"):
                queryset = await self.afilter_queryset(self.get_queryset())

            try:
                async with db_slot():
                    with db_operation():
                        page = await self.apaginate_queryset(queryset)
            except DBAdmissionTimeout:
                with view_stage("view.response.busy"):
                    response = Response(
                        {"detail": "The database is temporarily busy. Please retry."},
                        status=503,
                    )
                    response["Retry-After"] = "1"
                    return response

            if page is not None:
                with view_stage("view.serializer.instantiate"):
                    serializer = self.get_serializer(page, many=True)
                with view_stage("view.serializer.adata"):
                    data = await AsyncSerializerService.adata(serializer)
                return await self.get_apaginated_response(data)

            with view_stage("view.serializer.instantiate"):
                serializer = self.get_serializer(queryset, many=True)
            with view_stage("view.serializer.adata"):
                data = await AsyncSerializerService.adata(serializer)
            with view_stage("view.response.unpaginated"):
                return Response(data, status=200)

    def get_queryset(self):
        with view_stage("view.queryset.sold_subquery"):
            sold_subquery = self._confirmed_invoice_item_qty()
        with view_stage("view.queryset.stock_subquery"):
            stock_subquery = self._total_stock_subquery()
        with view_stage("view.queryset.annotate"):
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
            name = backend_class.__name__.removesuffix("Filter").lower()
            with view_stage(f"view.filter.{name}"):
                queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    def get_queryset(self):
        return CartonPricing.objects.all()
