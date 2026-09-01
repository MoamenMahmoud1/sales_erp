import os

if os.environ.get("BENCH_API_STACK", "async").lower() == "sync":
    from rest_framework.routers import SimpleRouter
    from .api.sync_views import CartonPricingViewSet, ProductViewSet
else:
    from adrf.routers import SimpleRouter
    from .api.views import CartonPricingViewSet, ProductViewSet

app_name = "products"

router = SimpleRouter()
router.register("products", ProductViewSet, basename="product")
router.register("carton-pricings", CartonPricingViewSet, basename="cartonpricing")

urlpatterns = router.urls
