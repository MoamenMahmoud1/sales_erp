"""ASGI entry point for the ERP backend.

In production this module is loaded by a proper ASGI server (uvicorn/gunicorn
workers). The development ``manage.py runserver`` also uses ASGI.

The native async PostgreSQL pool is opened during ASGI lifespan startup and
closed during shutdown. The pool module never opens connections at import time,
which keeps Gunicorn ``preload_app`` safe.
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_dev")

if os.environ.get("DJANGO_SETTINGS_MODULE") == "core.settings.settings_bench":
    os.environ["BENCH_API_STACK"] = "async"

_django_application = get_asgi_application()


async def application(scope, receive, send):
    """Serve Django requests and own the native async DB pool lifespan."""
    if scope["type"] != "lifespan":
        await _django_application(scope, receive, send)
        return

    from common.services.async_postgres import close_pool, open_pool

    while True:
        message = await receive()
        message_type = message["type"]

        if message_type == "lifespan.startup":
            try:
                await open_pool(wait=True)
            except Exception as exc:  # pragma: no cover - exercised by ASGI server
                await send(
                    {
                        "type": "lifespan.startup.failed",
                        "message": str(exc),
                    }
                )
                return
            await send({"type": "lifespan.startup.complete"})
        elif message_type == "lifespan.shutdown":
            try:
                await close_pool()
            finally:
                await send({"type": "lifespan.shutdown.complete"})
            return
