from django.conf import settings
from django.utils import timezone
from adrf import mixins, viewsets
from adrf.views import APIView
from asgiref.sync import sync_to_async
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from authsession.api.serializers import (
    AuthSessionSerializer,
    AuthSessionVerificationSerializer,
)
from authsession.http import NoStoreResponseMixin, clear_login_cookies, get_device_id
from authsession.models import AuthSession
from authsession.permissions import CurrentAuthSessionPermission
from authsession.services import (
    AuthSessionTooNew,
    InvalidAuthSession,
)
from authsession.services.auth_session import averify_current_auth_session
from authentication.throttling import SensitiveActionThrottle


class AuthSessionVerificationView(NoStoreResponseMixin, APIView):
    permission_classes = (IsAuthenticated,)
    throttle_classes = (SensitiveActionThrottle,)

    async def post(self, request, *args, **kwargs):
        serializer = AuthSessionVerificationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        refresh_token = request.COOKIES.get("refresh_token")
        device_id = get_device_id(request)

        # The stateless JWT TokenUser lacks the password hash needed by the
        # authsession verification. Fetch the real user explicitly without
        # blocking the ASGI event loop.
        user = await self._resolve_user(request)

        try:
            if not refresh_token or device_id is None:
                raise InvalidAuthSession
            auth_session = await averify_current_auth_session(
                user=user,
                access_token=request.auth,
                refresh_token=refresh_token,
                device_id=device_id,
                password=serializer.validated_data["current_password"],
            )
        except AuthSessionTooNew as error:
            return Response(
                {
                    "detail": "This session is not old enough.",
                    "code": "session_too_new",
                    "eligible_at": error.eligible_at,
                },
                status=status.HTTP_403_FORBIDDEN,
            )
        except InvalidAuthSession:
            return Response(
                {
                    "detail": "Invalid authentication session or password.",
                    "code": "invalid_session_verification",
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        return Response(
            {
                "verified_until": (
                    auth_session.verified_at
                    + settings.AUTH_SESSION_VERIFICATION_TTL
                )
            },
            status=status.HTTP_200_OK,
        )

    @staticmethod
    async def _resolve_user(request):
        """Return the database User needed for stateful session verification."""
        from django.contrib.auth import get_user_model

        User = get_user_model()
        user_pk = request.user.pk
        if user_pk is None:
            raise AuthenticationFailed("Invalid authentication session.")
        try:
            return await User.objects.aget(pk=user_pk)
        except User.DoesNotExist as error:
            raise AuthenticationFailed(
                "Invalid authentication session."
            ) from error


class AuthSessionViewSet(
    NoStoreResponseMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = AuthSessionSerializer
    permission_classes = (IsAuthenticated, CurrentAuthSessionPermission)

    def get_queryset(self):
        return AuthSession.objects.filter(
            user_id=self.request.user.pk,
            revoked_at__isnull=True,
            expires_at__gt=timezone.now(),
        ).order_by("-last_refreshed_at")

    async def adestroy(self, request, *args, **kwargs):
        auth_session = await self.aget_object()
        is_current = get_device_id(request) == auth_session.device_id
        await sync_to_async(
            AuthSession.objects.filter(
                pk=auth_session.pk,
                revoked_at__isnull=True,
            ).update,
            thread_sensitive=True,
        )(revoked_at=timezone.now())

        response = Response(status=status.HTTP_204_NO_CONTENT)
        if is_current:
            clear_login_cookies(response)
        return response
