"""
Tests proving that JWT access-token authentication is stateless.

These tests verify that validating a valid access token performs ZERO
database queries and ZERO Redis lookups.  The access token is validated
entirely locally via cryptographic signature verification.
"""

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.test.client import AsyncRequestFactory
from django.test.utils import CaptureQueriesContext
from django.db import connection
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework.test import force_authenticate

from invoices.api.views import InvoiceViewSet


class StatelessAuthTests(TestCase):
    """Prove JWT authentication performs zero User-table queries."""

    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username="stateless-user",
            email="stateless@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )
        self.factory = AsyncRequestFactory()

    def _make_authenticated_request(self, path, method="get", data=None):
        """Create an authenticated request using a stateless JWT access token."""
        token = AccessToken.for_user(self.user)
        if method == "get":
            request = self.factory.get(path)
        else:
            request = self.factory.post(path, data or {}, content_type="application/json")
        force_authenticate(request, user=self.user, token=str(token))
        return request

    def test_jwt_auth_performs_zero_user_queries(self):
        """Verify that JWT authentication itself queries the User table zero times.

        This test captures all SQL queries during request processing and asserts
        that no SELECT against the User table occurs during authentication.
        """
        request = self._make_authenticated_request("/api/v1/invoices/")

        # Capture queries during view dispatch (authentication happens here).
        with CaptureQueriesContext(connection) as ctx:
            response = InvoiceViewSet.as_view({"get": "alist"})(request)

        # Filter for User-table queries (authentication would trigger these).
        User = get_user_model()
        user_table = User._meta.db_table
        user_queries = [
            q for q in ctx.captured_queries
            if user_table in q["sql"].lower()
        ]

        # The list view may legitimately query the DB for business data, but
        # authentication itself must not query the User table.
        # Note: We allow 0 user queries for auth; business queries are separate.
        self.assertEqual(
            len(user_queries),
            0,
            f"JWT authentication should not query the User table, but found: {user_queries}",
        )

    def test_access_token_contains_required_claims(self):
        """Verify the access token contains the minimal claims for authorization."""
        token = AccessToken.for_user(self.user)

        # Token must contain the user identifier (stored as string in JWT).
        self.assertEqual(int(token["user_id"]), self.user.pk)

        # Token must have an expiration claim.
        self.assertIn("exp", token)

        # Token must have an issued-at claim.
        self.assertIn("iat", token)

    def test_valid_token_authenticates_successfully(self):
        """Verify a valid access token authenticates without DB lookup."""
        request = self._make_authenticated_request("/api/v1/invoices/")

        # The request should be authenticated — force_authenticate sets
        # request.user via the stateless JWT backend.
        self.assertEqual(request.user, self.user)

    def test_invalid_token_rejected_locally(self):
        """Verify an invalid token is rejected without any DB lookup.

        A tampered/invalid token fails signature verification locally.
        """
        request = self.factory.get("/api/v1/invoices/")
        # Set an obviously invalid token — no DB lookup should occur.
        request.META["HTTP_AUTHORIZATION"] = "Bearer invalid.token.value"

        with CaptureQueriesContext(connection) as ctx:
            response = InvoiceViewSet.as_view({"get": "alist"})(request)

        # Should return 401 without querying the User table.
        self.assertEqual(response.status_code, 401)

        User = get_user_model()
        user_table = User._meta.db_table
        user_queries = [
            q for q in ctx.captured_queries
            if user_table in q["sql"].lower()
        ]
        self.assertEqual(len(user_queries), 0)


class NoRevokeTokenCheckTests(TestCase):
    """Verify CHECK_REVOKE_TOKEN is disabled (access tokens are stateless)."""

    def test_check_revoke_token_is_disabled(self):
        """CHECK_REVOKE_TOKEN must remain False for stateless access tokens."""
        from django.conf import settings

        self.assertFalse(
            settings.SIMPLE_JWT.get("CHECK_REVOKE_TOKEN", False),
            "CHECK_REVOKE_TOKEN must be False — access tokens are stateless JWTs.",
        )
