"""Benchmark settings for the production JSON API hot path."""

import os

from .settings_api import *  # noqa: F401,F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost"]

# The benchmark is API-only. The Django admin is intentionally not installed
# here because settings_api deliberately removes the admin/session/message
# middleware from the API hot path. This keeps Django system checks aligned
# with the process we actually benchmark.
INSTALLED_APPS = [
    app for app in INSTALLED_APPS if app != "django.contrib.admin"
]
ROOT_URLCONF = "core.benchmark_urls"

# Benchmark raw application capacity, not the configured rate-limit policy.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_THROTTLE_CLASSES": (),
}

# The benchmark can explicitly enable the Redis-backed Products read cache.
# Keep it off by default so the DB-only baseline remains reproducible.
PRODUCT_LIST_CACHE_ENABLED = os.getenv("PRODUCT_LIST_CACHE_ENABLED", "0").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
PRODUCT_LIST_CACHE_TTL = int(os.getenv("PRODUCT_LIST_CACHE_TTL", "30") or "30")
if PRODUCT_LIST_CACHE_TTL < 1:
    raise ValueError("PRODUCT_LIST_CACHE_TTL must be >= 1")

# Benchmark runs explicitly choose the admission limit through the environment.
ASYNC_DB_CONCURRENCY = int(os.getenv("ASYNC_DB_CONCURRENCY", "0") or "0")
if ASYNC_DB_CONCURRENCY < 0 or ASYNC_DB_CONCURRENCY >= DB_POOL_MAX_SIZE:
    raise ValueError(
        "ASYNC_DB_CONCURRENCY must be 0 or strictly less than DB_POOL_MAX_SIZE"
    )

# Calibration/diagnostic runs enable stage instrumentation; clean performance
# runs disable it so SQL sampling and response headers cannot inflate latency.
PERF_TIMING_ENABLED = os.getenv("PERF_TIMING_ENABLED", "0").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
