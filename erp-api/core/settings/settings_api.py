"""Production settings for the async JSON API process.

The API is authenticated by DRF's stateless JWT backend, so Django's
session/auth/message/CSRF middleware is not part of the API request path.
The admin/web process can continue using settings_prod.py unchanged.
"""

from .settings_prod import *  # noqa: F401,F403

# API-only middleware: keep proxy normalization, CORS, security headers and
# the single request-id/perf middleware. The API intentionally avoids
# thread-sensitive Django middleware that is not required for Bearer JWTs.
MIDDLEWARE = [
    "core.middleware.RequestIdAndPerfMiddleware",
    "core.middleware.TrustedProxyHeadersMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
]

# Match the benchmark-selected admission policy explicitly for API workers.
ASYNC_DB_CONCURRENCY = config("ASYNC_DB_CONCURRENCY", default=4, cast=int)
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY >= DB_POOL_MAX_SIZE:
    raise ValueError(
        "ASYNC_DB_CONCURRENCY must be 0 or strictly less than DB_POOL_MAX_SIZE"
    )
