"""Benchmark settings: production DB/cache/ASGI stack without request throttling."""

import os

from .settings_prod import *  # noqa: F401,F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost"]

# Benchmark-only instrumentation. It exposes request wall time and SQL time
# through response headers; it is never enabled by production settings.
_bench_minimal_middleware = os.getenv("BENCH_MINIMAL_MIDDLEWARE", "0") == "1"
_bench_middleware_diagnostic = os.getenv("BENCH_MIDDLEWARE_DIAGNOSTIC", "0") == "1"
if _bench_minimal_middleware:
    # The products benchmark is authenticated by DRF's stateless JWT
    # authentication, so the Django AuthenticationMiddleware/session stack is
    # not required for this read-only endpoint. This gives us a true
    # end-to-end async middleware comparison.
    MIDDLEWARE = [
        "benchmarks.request_timing_middleware.BenchmarkTimingMiddleware",
    ]
else:
    MIDDLEWARE = [
        "benchmarks.request_timing_middleware.BenchmarkTimingMiddleware",
        *MIDDLEWARE,
    ]

# Diagnostic mode patches the configured middleware classes at import time and
# records inclusive wall time for each invocation. It is opt-in and only used
# by the disposable benchmark environment.
if _bench_middleware_diagnostic:
    from benchmarks.middleware_probe import install_middleware_probe

    install_middleware_probe(MIDDLEWARE)

# Application-level DB concurrency control. Zero disables the gate. When
# enabled, the async view waits here before entering its DB-bound section,
# preventing Django's PostgreSQL pool from becoming the primary request queue.
ASYNC_DB_CONCURRENCY = int(os.getenv("ASYNC_DB_CONCURRENCY", "0") or "0")
if ASYNC_DB_CONCURRENCY < 0:
    raise ValueError("ASYNC_DB_CONCURRENCY must be >= 0")

# Benchmark raw application capacity, not the configured rate-limit policy.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_CLASSES": (),
}
