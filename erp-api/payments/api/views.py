"""Async payment/collection API.

The collection write path runs the whole operation through one synchronous
``ProcessCollection`` boundary (transaction + locks).  Transactions are
read-only through the API.

Optional ``Idempotency-Key`` header: if supplied, a repeat request with the
same key + body returns the previously stored response instead of
re-executing.  Keys are DB-backed (never Redis-only) to guarantee
financial durability.
"""

from asgiref.sync import sync_to_async
from adrf import generics
from adrf.views import APIView
from django.db.models import Prefetch
from rest_framework import status
from rest_framework.response import Response

from common.exceptions import InvalidBusinessOperation, InvalidMoney
from common.pagination import StandardPagination
from common.observability import log_operation
from customers.models import Customer
from payments.api.serializers import (
    CollectionSerializer,
    PaymentTransactionSerializer,
)
from payments.models import IdempotencyKey, PaymentAllocation, PaymentTransaction
from payments.permissions import CollectionPermission, TransactionReadPermission
from payments.services import (
    NoConfirmableInvoicesError,
    OverpaymentError,
    ProcessCollection,
    _lookup_idempotency_sync,
    _record_idempotency_sync,
)
from authentication.throttling import SensitiveActionThrottle


class CollectionView(APIView):
    """POST /api/v1/payments/collections/ — receive and allocate a payment."""

    permission_classes = (CollectionPermission,)
    throttle_classes = (SensitiveActionThrottle,)

    async def post(self, request, *args, **kwargs):
        serializer = CollectionSerializer(data=request.data)
        await sync_to_async(
            serializer.is_valid,
            thread_sensitive=True,
        )(raise_exception=True)

        customer = serializer.validated_data["customer"]
        cash_amount = serializer.validated_data["cash_amount"]
        transfer_amount = serializer.validated_data["transfer_amount"]

        idempotency_key = request.headers.get("Idempotency-Key")
        request_data = {
            "customer": customer.pk,
            "cash_amount": str(cash_amount),
            "transfer_amount": str(transfer_amount),
        }

        # Idempotency: return stored response if the same key was used before.
        if idempotency_key:
            existing = await sync_to_async(
                _lookup_idempotency_sync,
                thread_sensitive=True,
            )(
                key=idempotency_key,
                user=request.user,
                path=request.path,
                data=request_data,
            )
            if existing == "mismatch":
                return Response(
                    {
                        "detail": "Idempotency key used with a different request body.",
                        "code": "idempotency_conflict",
                    },
                    status=status.HTTP_409_CONFLICT,
                )
            if existing is not None:
                return Response(
                    existing.response_body,
                    status=existing.response_status,
                )

        try:
            payment = await ProcessCollection()(
                customer=customer,
                cash_amount=cash_amount,
                transfer_amount=transfer_amount,
            )
        except OverpaymentError as exc:
            log_operation("payment.collection", user=request.user.pk,
                          customer=customer.pk, result="overpayment_rejected")
            response = Response(
                {"detail": str(exc), "code": "overpayment"},
                status=status.HTTP_400_BAD_REQUEST,
            )
            await self._maybe_record_idempotency(request, request_data,
                                                  idempotency_key, response)
            return response
        except NoConfirmableInvoicesError as exc:
            log_operation("payment.collection", user=request.user.pk,
                          customer=customer.pk, result="no_invoices_rejected")
            response = Response(
                {"detail": str(exc), "code": "nothing_to_collect"},
                status=status.HTTP_400_BAD_REQUEST,
            )
            await self._maybe_record_idempotency(request, request_data,
                                                  idempotency_key, response)
            return response
        except (InvalidMoney, InvalidBusinessOperation) as exc:
            log_operation("payment.collection", user=request.user.pk,
                          customer=customer.pk, result="invalid_rejected")
            response = Response(
                {"detail": str(exc), "code": "invalid_payment"},
                status=status.HTTP_400_BAD_REQUEST,
            )
            await self._maybe_record_idempotency(request, request_data,
                                                  idempotency_key, response)
            return response

        if payment is None:
            log_operation("payment.collection", user=request.user.pk,
                          customer=customer.pk, result="noop")
            response = Response(
                {"detail": "Zero-value collection is a no-op.",
                 "code": "noop"},
                status=status.HTTP_200_OK,
            )
            await self._maybe_record_idempotency(request, request_data,
                                                  idempotency_key, response)
            return response

        response_serializer = PaymentTransactionSerializer(payment)
        data = await sync_to_async(
            lambda: response_serializer.data,
            thread_sensitive=True,
        )()
        response = Response(data, status=status.HTTP_201_CREATED)
        await self._maybe_record_idempotency(request, request_data,
                                              idempotency_key, response)
        return response

    async def _maybe_record_idempotency(self, request, data, key, response):
        """Persist the idempotency record if a key was supplied."""
        if not key:
            return
        await sync_to_async(
            _record_idempotency_sync,
            thread_sensitive=True,
        )(
            key=key,
            user=request.user,
            path=request.path,
            data=data,
            status_code=response.status_code,
            body=response.data,
        )


class TransactionListView(generics.ListAPIView):
    """GET /api/v1/payments/transactions/ — read-only view of collections."""

    serializer_class = PaymentTransactionSerializer
    pagination_class = StandardPagination
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
