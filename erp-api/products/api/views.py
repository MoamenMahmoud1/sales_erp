import os

from adrf import viewsets
from rest_framework import filters
from rest_framework.response import Response

from common.pagination import AsyncCursorPagination, AsyncStandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission
from common.services.async_db_gate import DBAdmissionTimeout
from common.services.async_postgres import enabled as native_async_db_enabled
from common.services.async_serializer import AsyncSerializerService
from common.services.perf_timing import timed_function, view_stage
from products.api.serializers import CartonPricingSerializer, ProductSerializer
from products.models import CartonPricing
from products.services import cache as product_cache
from products.services.metrics import ProductMetricsQueryService
from products.services.native_async_list import NativeProductListService


_BENCH_PAGINATION = os.getenv("BENCH_PAGINATION", "page").lower()


class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = (
        ReadAuthenticatedWriteStaffPermission,
    )
    pagination_class = (
        AsyncCursorPagination if _BENCH_PAGINATION == "cursor" else AsyncStandardPagination
    )

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

    @timed_function("ProductViewSet.afilter_queryset")
    async def afilter_queryset(self, queryset):
        for backend_class in self.filter_backends:
            name = backend_class.__name__.removesuffix("Filter").lower()
            with view_stage(f"view.filter.{name}"):
                queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    @timed_function("ProductViewSet.alist")
    async def alist(self, request, *args, **kwargs):
        cache_key = product_cache.make_key(request.path, request.query_params)
        if product_cache.enabled():
            with view_stage("view.redis.cache.get"):
                cached = await product_cache.get_async(cache_key)
            if cached is not None:
                with view_stage("view.redis.cache.hit"):
                    return Response(cached, status=200)

        # Use native psycopg AsyncConnectionPool for the hot page-number read.
        # Cursor pagination and the special `last` page keep the existing ORM
        # implementation until they receive an equivalent native cursor layer.
        if native_async_db_enabled() and isinstance(
            self.pagination_class, type
        ) and issubclass(self.pagination_class, AsyncStandardPagination):
            try:
                response = await NativeProductListService.response(
                    request, self.get_serializer_class()
                )
            except NotImplementedError:
                pass
            else:
                if product_cache.enabled() and response.status_code == 200:
                    with view_stage("view.redis.cache.set"):
                        await product_cache.set_async(cache_key, response.data)
                return response

        with view_stage("view.total"):
            with view_stage("view.queryset.build"):
                queryset = await self.afilter_queryset(self.get_queryset())

            try:
                # Pagination owns admission around each actual DB execution for
                # the legacy Django async ORM fallback path.
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
                response = await self.get_apaginated_response(data)
                if product_cache.enabled() and response.status_code == 200:
                    with view_stage("view.redis.cache.set"):
                        await product_cache.set_async(cache_key, response.data)
                return response

            with view_stage("view.serializer.instantiate"):
                serializer = self.get_serializer(queryset, many=True)
            with view_stage("view.serializer.adata"):
                data = await AsyncSerializerService.adata(serializer)
            with view_stage("view.response.unpaginated"):
                response = Response(data, status=200)
            if product_cache.enabled():
                with view_stage("view.redis.cache.set"):
                    await product_cache.set_async(cache_key, response.data)
            return response

    @timed_function("ProductViewSet.get_queryset")
    def get_queryset(self):
        with view_stage("view.queryset.annotate"):
            return ProductMetricsQueryService.with_metrics()


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
