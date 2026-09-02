"""Minimal API URL configuration used only by the benchmark process."""

from django.urls import include, path
from .views import health_live, health_ready, version_view

urlpatterns = [
    path("health/live/", health_live, name="health-live"),
    path("health/ready/", health_ready, name="health-ready"),
    path("api/v1/system/version/", version_view, name="system-version"),
    path("api/v1/", include(("accounts.urls", "accounts"), namespace="accounts")),
    path("api/v1/", include(("customers.urls", "customers"), namespace="customers")),
    path("api/v1/", include(("products.urls", "products"), namespace="products")),
    path("api/v1/", include(("coupons.urls", "coupons"), namespace="coupons")),
    path("api/v1/", include(("invoices.urls", "invoices"), namespace="invoices")),
    path("api/v1/payments/", include(("payments.urls", "payments"), namespace="payments")),
    path("api/v1/purchases/", include("purchases.urls")),
    path("api/v1/suppliers/", include("suppliers.urls")),
]
