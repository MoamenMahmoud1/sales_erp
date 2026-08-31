from django.conf import settings
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied
from rest_framework.permissions import BasePermission

from authsession.http import get_device_id
from authsession.services import InvalidAuthSession, get_current_auth_session


class CurrentAuthSessionPermission(BasePermission):
    """Verify the stateful auth session for the authenticated user.

    The access token is validated statelessly by the JWT authentication class.
    This permission performs a SEPARATE, stateful check against the
    ``authsession`` system, which requires the real User object (for password
    hash verification).  Fetching the user here is explicit business logic for
    session management — it is NOT part of access-token authentication.
    """

    def has_permission(self, request, view):
        refresh_token = request.COOKIES.get("refresh_token")
        device_id = get_device_id(request)
        if not refresh_token or device_id is None:
            raise AuthenticationFailed("Invalid authentication session.")

        # The stateless JWT ``TokenUser`` lacks the password hash needed by the
        # authsession verification.  Fetch the real user explicitly — this is a
        # business lookup for the stateful session system, not a JWT auth check.
        user = self._resolve_user(request)

        try:
            auth_session = get_current_auth_session(
                user=user,
                access_token=request.auth,
                refresh_token=refresh_token,
                device_id=device_id,
            )
        except InvalidAuthSession as error:
            raise AuthenticationFailed(
                "Invalid authentication session."
            ) from error

        request.auth_session = auth_session
        return True

    def _resolve_user(self, request):
        """Return the database User needed for stateful session verification.

        ``request.user`` is the stateless JWT ``TokenUser``.  The authsession
        service needs the real user's password hash, so we fetch it here.
        """
        from django.contrib.auth import get_user_model

        User = get_user_model()
        user_pk = request.user.pk
        if user_pk is None:
            raise AuthenticationFailed("Invalid authentication session.")
        try:
            return User.objects.get(pk=user_pk)
        except User.DoesNotExist as error:
            raise AuthenticationFailed(
                "Invalid authentication session."
            ) from error


class VerifiedAuthSessionPermission(CurrentAuthSessionPermission):
    def has_permission(self, request, view):
        super().has_permission(request, view)
        auth_session = request.auth_session

        if (
            auth_session.verified_at is None
            or auth_session.verified_at
            < timezone.now() - settings.AUTH_SESSION_VERIFICATION_TTL
        ):
            raise PermissionDenied(
                "Recent session verification is required.",
                code="session_verification_required",
            )

        return True
