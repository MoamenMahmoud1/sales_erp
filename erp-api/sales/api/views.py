from django.db.models import Prefetch, Sum
from rest_framework.viewsets import ModelViewSet

from ..models import Coupon, Customer, Invoice, InvoiceItem, Payment, Product
from ..permissions import SalesAccessPermission
from .serializers import (
    CouponSerializer,
    CustomerSerializer,
    InvoiceSerializer,
    InvoiceSummarySerializer,
    PaymentSerializer,
    ProductSerializer,
)


class CustomerViewSet(ModelViewSet):
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    permission_classes = (SalesAccessPermission,)


class ProductViewSet(ModelViewSet):
    queryset = (
        Product.objects.annotate(_sold_quantity=Sum("invoice_items__quantity"))
        .order_by("name", "pk")
    )
    serializer_class = ProductSerializer
    permission_classes = (SalesAccessPermission,)


class CouponViewSet(ModelViewSet):
    queryset = Coupon.objects.all()
    serializer_class = CouponSerializer
    permission_classes = (SalesAccessPermission,)


class PaymentViewSet(ModelViewSet):
    queryset = Payment.objects.select_related("invoice", "invoice__customer")
    serializer_class = PaymentSerializer
    permission_classes = (SalesAccessPermission,)


class InvoiceViewSet(ModelViewSet):
    permission_classes = (SalesAccessPermission,)

    def get_queryset(self):
        return Invoice.objects.select_related("customer", "created_by", "coupon").prefetch_related(
            Prefetch("items", queryset=InvoiceItem.objects.select_related("product")),
            "payments",
        )

    def get_serializer_class(self):
        if self.action in {"list", "retrieve"}:
            return InvoiceSummarySerializer
        return InvoiceSerializer
