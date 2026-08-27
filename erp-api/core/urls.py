from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from .views import version_view

urlpatterns = [
    path("api/v1/system/version/", version_view, name="system-version"),
    path("api/v1/", include(("accounts.urls", "accounts"), namespace="accounts")),
    path(
        "api/v1/organization/",
        include(("organization.urls", "organization"), namespace="organization"),
    ),
    path("api/v1/", include(("customers.urls", "customers"), namespace="customers")),
    path("api/v1/", include(("products.urls", "products"), namespace="products")),
    path("api/v1/", include(("coupons.urls", "coupons"), namespace="coupons")),
    path("api/v1/", include(("invoices.urls", "invoices"), namespace="invoices")),
    #path("api/v1/", include(("payments./urls", "payments"), namespace="payments")),
    path("api/v1/purchases/",include("purchases.urls"),),
    path("api/v1/suppliers/",include("suppliers.urls"),),
    path("admin/", admin.site.urls),
]

if settings.DEBUG:
    if "silk" in settings.INSTALLED_APPS:
        urlpatterns.append(path("silk/", include("silk.urls", namespace="silk")))
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
