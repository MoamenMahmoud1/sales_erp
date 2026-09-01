"""Async payment/collection API."""

from adrf import generics
from adrf.views import APIView
from django.db.models import Prefetch
from rest_framework import status
from rest_framework.response import Response

from authentication.throttling import SensitiveActionThrottle
from common.exceptions import InvalidBusinessOperation, InvalidMoney
from common.pagination import AsyncStandardPagination
from common.services.async_serializer import AsyncSerializerService
from common.observability import log_operation
from payments.api.serializers import CollectionSerializer, PaymentTransactionSerializer
from payments.models import PaymentAllocation, PaymentTransaction
from payments.permissions import CollectionPermission, TransactionReadPermission
from payments.services import (
    NoConfirmableInvoicesError,
    OverpaymentError,
    ProcessCollection,
    ProcessCollectionIdempotent,
)


class CollectionView(APIView):
    """POST /api/v1/payments/collections/ — receive and allocate a payment."""

    permission_classes = (CollectionPermission,)
    throttle_classes = (SensitiveActionThrottle,)

    async def post(self, request, *args, **kwargs):
        serializer = CollectionSerializer(data=request.data)
        await AsyncSerializerService.ais_valid(serializer, raise_exception=True)

        customer = serializer.validated_data["customer"]
        cash_amount = serializer.validated_data["cash_amount"]
        transfer_amount = serializer.validated_data["transfer_amount"]

        idempotency_key = request.headers.get("Idempotency-Key")
        request_data = {
            "customer": customer.pk,
            "cash_amount": str(cash_amount),
            "transfer_amount": str(transfer_amount),
        }
        user_id = request.user.pk

        if idempotency_key:
            result = await ProcessCollectionIdempotent()(
                key=idempotency_key,
                user_id=user_id,
                path=request.path,
                data=request_data,
                customer=customer,
                cash_amount=cash_amount,
                transfer_amount=transfer_amount,
            )
            if result == "mismatch":
                return Response(
                    {
                        "detail": "Idempotency key used with a different request body.",
                        "code": "idempotency_conflict",
                    },
                    status=status.HTTP_409_CONFLICT,
                )
            if result is not None:
                return Response(result.response_body, status=result.response_status)

        try:
            payment = await ProcessCollection()(
                customer=customer,
                cash_amount=cash_amount,
                transfer_amount=transfer_amount,
                collected_by_id=user_id,
            )
        except OverpaymentError as exc:
            log_operation("payment.collection", user=user_id, customer=customer.pk, result="overpayment_rejected")
            return Response({"detail": str(exc), "code": "overpayment"}, status=status.HTTP_400_BAD_REQUEST)
        except NoConfirmableInvoicesError as exc:
            log_operation("payment.collection", user=user_id, customer=customer.pk, result="no_invoices_rejected")
            return Response({"detail": str(exc), "code": "nothing_to_collect"}, status=status.HTTP_400_BAD_REQUEST)
        except (InvalidMoney, InvalidBusinessOperation) as exc:
            log_operation("payment.collection", user=user_id, customer=customer.pk, result="invalid_rejected")
            return Response({"detail": str(exc), "code": "invalid_payment"}, status=status.HTTP_400_BAD_REQUEST)

        if payment is None:
            log_operation("payment.collection", user=user_id, customer=customer.pk, result="noop")
            return Response(
                {"detail": "Zero-value collection is a no-op.", "code": "noop"},
                status=status.HTTP_200_OK,
            )

        response_serializer = PaymentTransactionSerializer(payment)
        return Response(await response_serializer.adata, status=status.HTTP_201_CREATED)


class TransactionListView(generics.ListAPIView):
    """GET /api/v1/payments/transactions/ — read-only view of collections."""

    serializer_class = PaymentTransactionSerializer
    pagination_class = AsyncStandardPagination
    permission_classes = (TransactionReadPermission,)

    def get_queryset(self):
        return (
            PaymentTransaction.objects.select_related("customer")
            .prefetch_related(
                Prefetch(
                    "allocations",
                    queryset=PaymentAllocation.objects.select_related("invoice"),
                )
            )
            .order_by("-created_at")
        )
