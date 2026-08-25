from rest_framework.routers import SimpleRouter

from .api.views import PaymentViewSet

app_name = "payments"

router = SimpleRouter()
router.register("payments", PaymentViewSet, basename="payment")

urlpatterns = router.urls