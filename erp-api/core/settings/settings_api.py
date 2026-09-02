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

# The API uses the primary admission queue with deliberate DB-pool headroom.
# With the production default pool of 12, eight DB-bound operations per worker
# can execute concurrently while spare pool capacity remains available for
# framework/background queries. Tune both values from actual load testing.
ASYNC_DB_CONCURRENCY = config("ASYNC_DB_CONCURRENCY", default=8, cast=int)
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY >= DB_POOL_MAX_SIZE:
    raise ValueError(
        "ASYNC_DB_CONCURRENCY must be 0 or strictly less than DB_POOL_MAX_SIZE"
    )
