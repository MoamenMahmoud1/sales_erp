from django_filters.rest_framework import DjangoFilterBackend
from adrf import generics
from adrf.views import APIView
from rest_framework import filters, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from authentication.throttling import SensitiveActionThrottle
from common.pagination import AsyncStandardPagination
from common.services.async_serializer import AsyncSerializerService
from purchases.api.filters.purchase import PurchaseFilter
from purchases.api.serializers import PurchaseListSerializer, PurchaseSerializer
from purchases.models import Purchase
from purchases.permissions.purchase import PurchaseAccessPermission
from purchases.services.cancel_purchase import CancelPurchaseService
from purchases.services.confirm_purchase import ConfirmPurchaseService
from purchases.services.purchase import PurchaseWriteService


class PurchaseListCreateView(generics.ListCreateAPIView):
    permission_classes = (PurchaseAccessPermission,)
    pagination_class = AsyncStandardPagination

    filter_backends = (
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    )
    filterset_class = PurchaseFilter
    search_fields = ("reference", "supplier__name")
    ordering_fields = ("created_at", "updated_at", "status")
    ordering = ("-created_at",)

    def get_queryset(self):
        return Purchase.objects.with_purchase_data().visible_to(self.request.user)

    def get_serializer_class(self):
        if self.request.method == "GET":
            return PurchaseListSerializer
        return PurchaseSerializer

    async def acreate(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        await AsyncSerializerService.ais_valid(serializer, raise_exception=True)

        purchase = await PurchaseWriteService.acreate(
            validated_data=serializer.validated_data,
            user=request.user,
        )
        purchase = await Purchase.objects.with_purchase_data().aget(pk=purchase.pk)
        response_serializer = PurchaseSerializer(
            purchase,
            context={"request": request},
        )
        return Response(await response_serializer.adata, status=status.HTTP_201_CREATED)


class PurchaseDetailView(generics.RetrieveAPIView):
    permission_classes = (PurchaseAccessPermission,)
    serializer_class = PurchaseSerializer

    def get_queryset(self):
        return Purchase.objects.with_purchase_data().visible_to(self.request.user)


class PurchaseConfirmView(APIView):
    permission_classes = (PurchaseAccessPermission,)
    permission_codename = "purchases.confirm_purchase"
    throttle_classes = (SensitiveActionThrottle,)

    async def post(self, request, pk):
        try:
            purchase = await ConfirmPurchaseService.aexecute(
                purchase_id=pk,
                created_by_id=request.user.pk,
            )
        except Purchase.DoesNotExist:
            return Response({"detail": "Purchase not found."}, status=status.HTTP_404_NOT_FOUND)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        purchase = await Purchase.objects.with_purchase_data().aget(pk=purchase.pk)
        serializer = PurchaseSerializer(purchase, context={"request": request})
        return Response(await serializer.adata, status=status.HTTP_200_OK)


class PurchaseCancelView(APIView):
    permission_classes = (PurchaseAccessPermission,)
    permission_codename = "purchases.cancel_purchase"
    throttle_classes = (SensitiveActionThrottle,)

    async def post(self, request, pk):
        try:
            purchase = await CancelPurchaseService.aexecute(purchase_id=pk)
        except Purchase.DoesNotExist:
            return Response({"detail": "Purchase not found."}, status=status.HTTP_404_NOT_FOUND)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        purchase = await Purchase.objects.with_purchase_data().aget(pk=purchase.pk)
        serializer = PurchaseSerializer(purchase, context={"request": request})
        return Response(await serializer.adata, status=status.HTTP_200_OK)


class PurchaseDeleteView(generics.DestroyAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = (PurchaseAccessPermission,)

    def get_queryset(self):
        return Purchase.objects.visible_to(self.request.user)

    async def perform_destroy(self, instance):
        if instance.status != Purchase.Status.DRAFT:
            raise ValidationError("Only draft purchases can be deleted.")
        await instance.adelete()
