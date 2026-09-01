from adrf.views import APIView
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


User = get_user_model()


class CurrentUserView(APIView):
    permission_classes = (IsAuthenticated,)

    async def get(self, request):
        # JWT authentication intentionally returns a stateless TokenUser.
        # This endpoint genuinely needs user profile fields, so perform one
        # explicit async User query without blocking the ASGI event loop.
        user = await User.objects.aget(pk=request.user.pk)
        return Response(
            {
                "id": user.pk,
                "username": user.username,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "is_staff": user.is_staff,
                "is_superuser": user.is_superuser,
            }
        )
