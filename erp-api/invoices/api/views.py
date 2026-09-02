"""Async ASGI views for immutable invoice operations."""

from decimal import Decimal

from adrf import viewsets
from django.db.models import Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.response import Response

from authentication.throttling import SensitiveActionThrottle

from common.exceptions import (
    CouponInvalid,
    InsufficientStock,
    InvalidBusinessOperation,
    InvalidDiscount,
    InvalidStateTransition,
)
from common.services.async_serializer import AsyncSerializerService
from invoices.api.serializers import InvoiceSerializer, InvoiceSummarySerializer
from invoices.models import Invoice, InvoiceItem
from invoices.permissions import InvoicePermission
from invoices.services import (
    ApplyCoupon,
    CancelInvoice,
    ConfirmInvoice,
    CreateInvoice,
    InvoiceNotFound,
)


async def _invoice_response(operation):
    """Run an async use case and translate its domain errors to HTTP."""
    try:
        invoice = await operation()
    except InvalidStateTransition as exc:
        return Response(
            {"detail": str(exc), "code": "invalid_state_transition"},
            status=status.HTTP_409_CONFLICT,
        )
    except (CouponInvalid, InvalidDiscount) as exc:
        return Response(
            {"detail": str(exc), "code": "coupon_invalid"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    except InsufficientStock as exc:
        return Response(
            {"detail": str(exc), "code": "insufficient_stock"},
            status=status.HTTP_409_CONFLICT,
        )
    except InvoiceNotFound as exc:
        return Response(
            {"detail": str(exc), "code": "not_found"},
            status=status.HTTP_404_NOT_FOUND,
        )
    except InvalidBusinessOperation as exc:
        return Response(
            {"detail": str(exc), "code": "invalid_operation"},
            status=status.HTTP_409_CONFLICT,
        )

    serializer = InvoiceSerializer(invoice)
    return Response(await serializer.adata, status=status.HTTP_200_OK)


class InvoiceViewSet(viewsets.ModelViewSet):
    """List, retrieve, and create invoices plus explicit lifecycle actions."""

    permission_classes = (InvoicePermission,)
    http_method_names = ("get", "post", "head", "options")

    def get_queryset(self):
        paid_amount = (
            Coalesce(
                Sum("payment_allocations__cash_amount"),
                Value(Decimal("0")),
            )
            + Coalesce(
                Sum("payment_allocations__transfer_amount"),
                Value(Decimal("0")),
            )
        )
        return (
            Invoice.objects.select_related(
                "customer",
                "created_by",
                "coupon",
            )
            .prefetch_related(
                "items__product",
            )
            .annotate(_paid_amount=paid_amount)
        )

    def get_serializer_class(self):
        if self.action in {"list", "retrieve", "alist", "aretrieve"}:
            return InvoiceSummarySerializer
        return InvoiceSerializer

    async def acreate(self, request, *args, **kwargs):
        """Validate input, then delegate persistence to the invoice service."""
        serializer = self.get_serializer(data=request.data)
        await AsyncSerializerService.ais_valid(serializer, raise_exception=True)

        invoice = await CreateInvoice()(
            created_by_id=request.user.pk,
            validated_data=serializer.validated_data,
        )
        response_serializer = InvoiceSerializer(invoice)
        return Response(
            await response_serializer.adata,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], throttle_classes=[SensitiveActionThrottle])
    async def confirm(self, request, pk=None):
        return await _invoice_response(
            lambda: ConfirmInvoice()(invoice_id=pk)
        )

    @action(detail=True, methods=["post"], throttle_classes=[SensitiveActionThrottle])
    async def cancel(self, request, pk=None):
        return await _invoice_response(
            lambda: CancelInvoice()(invoice_id=pk)
        )

    @action(detail=True, methods=["post"], url_path="apply-coupon", throttle_classes=[SensitiveActionThrottle])
    async def apply_coupon(self, request, pk=None):
        code = (request.data or {}).get("code")
        if not code:
            return Response(
                {"detail": "A coupon code is required.", "code": "coupon_required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return await _invoice_response(
            lambda: ApplyCoupon()(invoice_id=pk, code=code)
        )
