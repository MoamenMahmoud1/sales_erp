"""Reusable product metrics query builders for sync and async API paths."""

from __future__ import annotations

from django.db.models import OuterRef, Subquery, Sum, Value
from django.db.models.functions import Coalesce

from common.services.perf_timing import timed_function, view_stage
from products.models import Product


class ProductMetricsQueryService:
    """Build the same lazy metric expressions for sync and async views."""

    @staticmethod
    @timed_function("ProductMetricsQueryService.stock_subquery")
    def stock_subquery():
        from inventory.models import StockBalance

        with view_stage("view.service.stock.build"):
            return (
                StockBalance.objects.filter(product_id=OuterRef("pk"))
                .values("product_id")
                .annotate(total=Sum("quantity"))
                .values("total")
            )

    @staticmethod
    @timed_function("ProductMetricsQueryService.sold_subquery")
    def sold_subquery():
        from invoices.models import Invoice, InvoiceItem

        with view_stage("view.service.sold.build"):
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

    @classmethod
    @timed_function("ProductMetricsQueryService.with_metrics")
    def with_metrics(cls):
        with view_stage("view.queryset.metrics"):
            return Product.objects.annotate(
                _total_stock=Coalesce(
                    Subquery(cls.stock_subquery()),
                    Value(0),
                ),
                _sold_quantity=Coalesce(
                    Subquery(cls.sold_subquery()),
                    Value(0),
                ),
            )
