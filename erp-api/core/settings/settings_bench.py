"""Benchmark settings: production DB/cache/ASGI stack without request throttling."""

from .settings_prod import *  # noqa: F401,F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost"]

# Benchmark-only instrumentation. It exposes request wall time and SQL time
# through response headers; it is never enabled by production settings.
MIDDLEWARE = [
    "benchmarks.request_timing_middleware.BenchmarkTimingMiddleware",
    *MIDDLEWARE,
]

# Benchmark raw application capacity, not the configured rate-limit policy.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_CLASSES": (),
}
