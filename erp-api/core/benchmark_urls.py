"""URL configuration used by the API-only benchmark process."""

from django.urls import include, path

from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)

from .views import health_live, health_ready, version_view

urlpatterns = [
    path("health/live/", health_live, name="health-live"),
    path("health/ready/", health_ready, name="health-ready"),
    path("api/v1/system/version/", version_view, name="system-version"),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/v1/docs/swagger/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    path(
        "api/v1/docs/redoc/",
        SpectacularRedocView.as_view(url_name="schema"),
        name="redoc",
    ),
    path("api/v1/", include(("accounts.urls", "accounts"), namespace="accounts")),
    path(
        "api/v1/organization/",
        include(("organization.urls", "organization"), namespace="organization"),
    ),
    path("api/v1/", include(("customers.urls", "customers"), namespace="customers")),
    path("api/v1/", include(("products.urls", "products"), namespace="products")),
    path("api/v1/", include(("coupons.urls", "coupons"), namespace="coupons")),
    path("api/v1/", include(("invoices.urls", "invoices"), namespace="invoices")),
    path(
        "api/v1/payments/",
        include(("payments.urls", "payments"), namespace="payments"),
    ),
    path("api/v1/purchases/", include("purchases.urls")),
    path("api/v1/suppliers/", include("suppliers.urls")),
]
