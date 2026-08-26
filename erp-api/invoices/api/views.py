from django.db.models import Prefetch
from rest_framework import status as http_status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from common.exceptions import (
    CouponInvalid,
    InvalidDiscount,
    InvalidStateTransition,
)
from common.permissions import ReadAuthenticatedWriteStaffPermission
from invoices.api.serializers import (
    InvoiceSerializer,
    InvoiceSummarySerializer,
)
from invoices.models import Invoice, InvoiceItem
from invoices.services import (
    ApplyCoupon,
    CancelInvoice,
    ConfirmInvoice,
    InvoiceNotFound,
)


def _invoice_action(operation, serializer_class):
    """Run a business operation, translating domain errors to HTTP errors."""
    try:
        invoice = operation()
    except InvalidStateTransition as exc:
        return Response(
            {"detail": str(exc), "code": "invalid_state_transition"},
            status=http_status.HTTP_409_CONFLICT,
        )
    except (CouponInvalid, InvalidDiscount) as exc:
        return Response(
            {"detail": str(exc), "code": "coupon_invalid"},
            status=http_status.HTTP_400_BAD_REQUEST,
        )
    except InvoiceNotFound as exc:
        return Response(
            {"detail": str(exc), "code": "not_found"},
            status=http_status.HTTP_404_NOT_FOUND,
        )
    serializer = serializer_class(invoice)
    return Response(serializer.data, status=http_status.HTTP_200_OK)


class InvoiceViewSet(ModelViewSet):
    permission_classes = (ReadAuthenticatedWriteStaffPermission,)
    # Financial immutability: only creation and the explicit business actions
    # (confirm/cancel/apply-coupon) mutate invoices. No generic update/delete.
    http_method_names = ("get", "post", "head", "options")

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

    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        return _invoice_action(
            lambda: ConfirmInvoice()(invoice_id=pk),
            InvoiceSerializer,
        )

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        return _invoice_action(
            lambda: CancelInvoice()(invoice_id=pk),
            InvoiceSerializer,
        )

    @action(detail=True, methods=["post"], url_path="apply-coupon")
    def apply_coupon(self, request, pk=None):
        code = (request.data or {}).get("code")
        if not code:
            return Response(
                {"detail": "A coupon code is required.", "code": "coupon_required"},
                status=http_status.HTTP_400_BAD_REQUEST,
            )
        return _invoice_action(
            lambda: ApplyCoupon()(invoice_id=pk, code=code),
            InvoiceSerializer,
        )
