"""Benchmark settings using the real async application stack."""

import os

from .settings_prod import *  # noqa: F401,F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost"]

# Benchmark raw application capacity, not the configured rate-limit policy.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_CLASSES": (),
}

# Benchmark runs explicitly choose the admission limit through the environment.
ASYNC_DB_CONCURRENCY = int(os.getenv("ASYNC_DB_CONCURRENCY", "0") or "0")
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY > DB_POOL_MAX_SIZE:
    raise ValueError("ASYNC_DB_CONCURRENCY must be between 0 and DB_POOL_MAX_SIZE")

# Emit X-Perf-* and Server-Timing headers so the external benchmark can collect
# the internal stages without relying on Django debug instrumentation.
PERF_TIMING_ENABLED = True
