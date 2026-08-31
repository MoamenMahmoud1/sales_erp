#!/usr/bin/env python3
"""Gunicorn configuration for ASGI workers.

Run with:
    DJANGO_SETTINGS_MODULE=core.settings.settings_prod \\
    gunicorn core.asgi:application -k uvicorn_worker.UvicornWorker

Worker count defaults to ``$WEB_CONCURRENCY`` or ``(2 * CPUs) + 1``.
The database connection pool (psycopg ``pool`` extra) is configured in
``settings_prod.py`` — each ASGI worker gets its own pool, so the
effective max DB connections ~= ``workers * pool.max_size``.

PostgreSQL capacity rule:
    effective DB connections ~= workers * DB_POOL_MAX_SIZE
This must be bounded against PostgreSQL's max_connections.  Prefer
conservative defaults — horizontal scaling is safer than opening hundreds
of DB connections accidentally.

IMPORTANT: ``workers * DB_POOL_MAX_SIZE`` must not exceed PostgreSQL's
``max_connections`` (minus superuser_reserved_connections).  For example,
with ``WEB_CONCURRENCY=4`` and ``DB_POOL_MAX_SIZE=10``, the app opens at
most 40 connections.  Adjust these values together.
"""
import multiprocessing
import os

# Number of ASGI worker processes.
# Override with $WEB_CONCURRENCY in production.  The default formula is a
# starting point, not a universal optimum — consider PostgreSQL capacity.
workers = int(os.environ.get("WEB_CONCURRENCY", 0)) or (
    (multiprocessing.cpu_count() * 2) + 1
)

# Uvicorn ASGI worker from the standalone ``uvicorn-worker`` package.
# This is the recommended path for Gunicorn + Uvicorn deployment.
worker_class = "uvicorn_worker.UvicornWorker"

# Graceful shutdown window (seconds).
timeout = int(os.environ.get("GUNICORN_TIMEOUT", "120"))
graceful_timeout = 30
keepalive = 5

# Pre-load the application once per worker to avoid re-importing on reload.
preload_app = True

# Bind address.
bind = os.environ.get("BIND", "0.0.0.0:8000")

# Log to stdout/stderr (container-friendly).
accesslog = "-"
errorlog = "-"
loglevel = os.environ.get("GUNICORN_LOGLEVEL", "info").lower()

# Capture stdout/stderr into gunicorn error log.
capture_output = True

max_requests = int(os.environ.get("MAX_REQUESTS", "1000"))
max_requests_jitter = int(os.environ.get("MAX_REQUESTS_JITTER", "100"))


def when_ready(server):
    """Called just before the main process is ready to serve requests."""
    server.log.info("Starting ERP API with %d workers", workers)


def on_starting(server):
    """Called just before the master process is about to start."""
    server.log.info("ERP API master process starting")


def on_exit(server):
    """Called when the server is about to exit."""
    server.log.info("ERP API shutting down")
