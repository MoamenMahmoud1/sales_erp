"""Pure synchronous DRF implementation used by production-compatible tests/benchmarks."""

import os
import time

from rest_framework import filters, viewsets
from rest_framework.response import Response

from common.pagination import InfiniteScrollPagination, StandardPagination
from common.permissions import ReadAuthenticatedWriteStaffPermission
from common.services.perf_timing import add_serializer_cpu, db_operation, timed_function, view_stage
from products.api.serializers import CartonPricingSerializer, ProductSerializer
from products.models import CartonPricing
from products.services.metrics import ProductMetricsQueryService


_BENCH_PAGINATION = os.getenv("BENCH_PAGINATION", "page").lower()


class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)
    pagination_class = (
        InfiniteScrollPagination if _BENCH_PAGINATION == "cursor" else StandardPagination
    )

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

    @timed_function("ProductViewSet.filter_queryset")
    def filter_queryset(self, queryset):
        for backend_class in self.filter_backends:
            name = backend_class.__name__.removesuffix("Filter").lower()
            with view_stage(f"view.filter.{name}"):
                queryset = backend_class().filter_queryset(self.request, queryset, self)
        return queryset

    @timed_function("ProductViewSet.list")
    def list(self, request, *args, **kwargs):
        with view_stage("view.total"):
            with view_stage("view.queryset.build"):
                queryset = self.filter_queryset(self.get_queryset())

            with db_operation():
                page = self.paginate_queryset(queryset)

            if page is not None:
                with view_stage("view.serializer.instantiate"):
                    serializer = self.get_serializer(page, many=True)
                with view_stage("view.serializer.data"):
                    started = time.perf_counter_ns()
                    try:
                        data = serializer.data
                    finally:
                        add_serializer_cpu(time.perf_counter_ns() - started)
                with view_stage("view.response.paginated"):
                    return self.get_paginated_response(data)

            with view_stage("view.serializer.instantiate"):
                serializer = self.get_serializer(queryset, many=True)
            with view_stage("view.serializer.data"):
                started = time.perf_counter_ns()
                try:
                    data = serializer.data
                finally:
                    add_serializer_cpu(time.perf_counter_ns() - started)
            with view_stage("view.response.unpaginated"):
                return Response(data, status=200)

    @timed_function("ProductViewSet.get_queryset")
    def get_queryset(self):
        with view_stage("view.queryset.annotate"):
            return ProductMetricsQueryService.with_metrics()


class CartonPricingViewSet(viewsets.ModelViewSet):
    serializer_class = CartonPricingSerializer
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)
    pagination_class = StandardPagination

    filter_backends = (filters.SearchFilter, filters.OrderingFilter)
    search_fields = ("name",)
    ordering_fields = (
        "name",
        "units_per_carton",
        "created_at",
        "updated_at",
    )
    ordering = ("name", "pk")

    @timed_function("CartonPricingViewSet.list")
    def list(self, request, *args, **kwargs):
        with view_stage("view.total"):
            queryset = self.filter_queryset(self.get_queryset())
            with db_operation():
                page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                data = serializer.data
                return self.get_paginated_response(data)
            serializer = self.get_serializer(queryset, many=True)
            return Response(data, status=200)

    def get_queryset(self):
        return CartonPricing.objects.all()
