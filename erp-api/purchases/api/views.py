from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from common.pagination import StandardPagination

from purchases.api.filters.purchase import PurchaseFilter
from purchases.api.serializers import PurchaseSerializer
from purchases.models import Purchase
from purchases.permissions.purchase import PurchaseAccessPermission
from purchases.services.cancel_purchase import CancelPurchaseService
from purchases.services.confirm_purchase import ConfirmPurchaseService


class PurchaseListCreateView(generics.ListCreateAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = (PurchaseAccessPermission,)
    pagination_class = StandardPagination

    filter_backends = (
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    )

    filterset_class = PurchaseFilter

    search_fields = (
        "reference",
        "supplier__name",
    )

    ordering_fields = (
        "created_at",
        "updated_at",
        "status",
    )

    ordering = ("-created_at",)

    def get_queryset(self):
        return Purchase.objects.for_list().visible_to(
            self.request.user,
        )


class PurchaseDetailView(generics.RetrieveAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = (PurchaseAccessPermission,)

    def get_queryset(self):
        return Purchase.objects.for_detail().visible_to(
            self.request.user,
        )


class PurchaseConfirmView(APIView):
    permission_classes = (PurchaseAccessPermission,)
    permission_codename = "purchases.confirm_purchase"

    def post(self, request, pk):
        try:
            purchase = ConfirmPurchaseService.execute(
                purchase_id=pk,
            )
        except Purchase.DoesNotExist:
            return Response(
                {"detail": "Purchase not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        except ValueError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            PurchaseSerializer(
                purchase,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PurchaseCancelView(APIView):
    permission_classes = (PurchaseAccessPermission,)
    permission_codename = "purchases.cancel_purchase"

    def post(self, request, pk):
        try:
            purchase = CancelPurchaseService.execute(
                purchase_id=pk,
            )
        except Purchase.DoesNotExist:
            return Response(
                {"detail": "Purchase not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        except ValueError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            PurchaseSerializer(
                purchase,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PurchaseDeleteView(generics.DestroyAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = (PurchaseAccessPermission,)

    def get_queryset(self):
        return Purchase.objects.visible_to(
            self.request.user,
        )

    def perform_destroy(self, instance):
        if instance.status != Purchase.Status.DRAFT:
            raise ValidationError(
                "Only draft purchases can be deleted."
            )

        instance.delete()