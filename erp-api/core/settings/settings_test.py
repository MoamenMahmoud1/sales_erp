"""Test settings built on the production configuration without HTTPS redirects."""

from .settings_prod import *  # noqa: F401,F403

# The Django test client speaks HTTP. Keep test cookies non-Secure so the
# stateful refresh/device cookies are sent back to subsequent test requests.
DEBUG = True
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
ALLOWED_HOSTS = ["testserver", "localhost", "127.0.0.1"]
