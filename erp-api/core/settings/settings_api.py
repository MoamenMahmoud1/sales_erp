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

# Native async PostgreSQL is opt-out. It is used only by explicitly migrated
# async hot paths; Django ORM and transactional writes retain their normal path.
ASYNC_NATIVE_DB = config("ASYNC_NATIVE_DB", default=True, cast=bool)
ASYNC_PG_POOL_MIN_SIZE = config("ASYNC_PG_POOL_MIN_SIZE", default=2, cast=int)
ASYNC_PG_POOL_MAX_SIZE = config(
    "ASYNC_PG_POOL_MAX_SIZE", default=DB_POOL_MAX_SIZE, cast=int
)
ASYNC_PG_POOL_TIMEOUT = config("ASYNC_PG_POOL_TIMEOUT", default=2.0, cast=float)
ASYNC_PG_POOL_MAX_LIFETIME = config(
    "ASYNC_PG_POOL_MAX_LIFETIME", default=3600.0, cast=float
)
ASYNC_PG_POOL_MAX_IDLE = config(
    "ASYNC_PG_POOL_MAX_IDLE", default=600.0, cast=float
)
ASYNC_PG_PREPARE_THRESHOLD = config(
    "ASYNC_PG_PREPARE_THRESHOLD", default=5, cast=int
)
if ASYNC_PG_POOL_MIN_SIZE < 0 or ASYNC_PG_POOL_MAX_SIZE < 1:
    raise ValueError("ASYNC_PG_POOL_MIN_SIZE and ASYNC_PG_POOL_MAX_SIZE are invalid")
if ASYNC_PG_POOL_MIN_SIZE > ASYNC_PG_POOL_MAX_SIZE:
    raise ValueError("ASYNC_PG_POOL_MIN_SIZE must be <= ASYNC_PG_POOL_MAX_SIZE")
if ASYNC_PG_POOL_TIMEOUT <= 0:
    raise ValueError("ASYNC_PG_POOL_TIMEOUT must be > 0")

# Retained only for the Django async ORM fallback path (for example, cursor
# pagination and endpoints not yet migrated to native async SQL).
ASYNC_DB_CONCURRENCY = config("ASYNC_DB_CONCURRENCY", default=8, cast=int)
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY >= DB_POOL_MAX_SIZE:
    raise ValueError(
        "ASYNC_DB_CONCURRENCY must be 0 or strictly less than DB_POOL_MAX_SIZE"
    )
