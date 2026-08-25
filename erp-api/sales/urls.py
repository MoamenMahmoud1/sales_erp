from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .api.views import (
    CouponViewSet,
    CustomerViewSet,
    InvoiceViewSet,
    PaymentViewSet,
    ProductViewSet,
)

app_name = "sales"
router = DefaultRouter()
router.register("customers", CustomerViewSet, basename="customer")
router.register("products", ProductViewSet, basename="product")
router.register("coupons", CouponViewSet, basename="coupon")
router.register("invoices", InvoiceViewSet, basename="invoice")
router.register("payments", PaymentViewSet, basename="payment")

urlpatterns = [path("", include(router.urls))]
