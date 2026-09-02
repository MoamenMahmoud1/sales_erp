"""Production settings for the async JSON API process."""

from .settings_prod import *  # noqa: F401,F403

# API-only hot path: the API uses stateless JWT authentication, so session,
# message, CSRF and Django auth middleware are deliberately excluded here.
MIDDLEWARE = [
    "core.middleware.RequestIdAndPerfMiddleware",
    "core.middleware.TrustedProxyHeadersMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
]

# Give the dedicated JSON API more DB pool headroom than the general web/admin
# process while keeping admission below the pool as the primary backpressure
# mechanism. Both values remain environment-overridable for real deployments.
DB_POOL_MIN_SIZE = config("DB_POOL_MIN_SIZE", default=2, cast=int)
DB_POOL_MAX_SIZE = config("DB_POOL_MAX_SIZE", default=12, cast=int)
if DB_POOL_MIN_SIZE < 0 or DB_POOL_MAX_SIZE < 1 or DB_POOL_MIN_SIZE > DB_POOL_MAX_SIZE:
    raise ValueError("DB_POOL_MIN_SIZE and DB_POOL_MAX_SIZE are invalid")

ASYNC_DB_CONCURRENCY = config("ASYNC_DB_CONCURRENCY", default=8, cast=int)
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY >= DB_POOL_MAX_SIZE:
    raise ValueError(
        "ASYNC_DB_CONCURRENCY must be 0 or strictly less than DB_POOL_MAX_SIZE"
    )
