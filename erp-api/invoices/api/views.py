from django.db.models import Prefetch
from rest_framework.viewsets import ModelViewSet

from common.permissions import ReadAuthenticatedWriteStaffPermission
from invoices.api.serializers import (
    InvoiceSerializer,
    InvoiceSummarySerializer,
)
from invoices.models import Invoice, InvoiceItem


class InvoiceViewSet(ModelViewSet):
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)

    def get_queryset(self):
        return Invoice.objects.select_related(
            "customer", "created_by", "coupon"
        ).prefetch_related(
            Prefetch(
                "items", queryset=InvoiceItem.objects.select_related("product")
            ),
            "payments",
        )

    def get_serializer_class(self):
        if self.action in {"list", "retrieve"}:
            return InvoiceSummarySerializer
        return InvoiceSerializer