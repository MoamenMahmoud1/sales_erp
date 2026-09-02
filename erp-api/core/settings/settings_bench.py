"""Benchmark-only settings for the synchronous API."""

from .settings_api import *  # noqa: F401,F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost"]
INSTALLED_APPS = [app for app in INSTALLED_APPS if app != "django.contrib.admin"]
ROOT_URLCONF = "core.benchmark_urls"
REST_FRAMEWORK = {**REST_FRAMEWORK, "DEFAULT_THROTTLE_CLASSES": ()}
DB_POOL_MIN_SIZE = int(os.getenv("DB_POOL_MIN_SIZE", str(DB_POOL_MAX_SIZE)))
DB_POOL_MAX_SIZE = int(os.getenv("DB_POOL_MAX_SIZE", "12"))
PRODUCT_LIST_CACHE_ENABLED = os.getenv("PRODUCT_LIST_CACHE_ENABLED", "0").lower() in {"1", "true", "yes", "on"}
PRODUCT_LIST_CACHE_TTL = int(os.getenv("PRODUCT_LIST_CACHE_TTL", "30"))
PERF_TIMING_ENABLED = False
