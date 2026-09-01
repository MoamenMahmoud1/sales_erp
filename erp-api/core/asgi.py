"""ASGI entry point for the ERP backend.

In production this module is loaded by a proper ASGI server (uvicorn/gunicorn
workers). The development ``manage.py runserver`` sets the development
settings module before importing this application.

Never use ``manage.py runserver`` in production.
"""
import os

from django.core.asgi import get_asgi_application

# Fail safe toward production when the ASGI module is invoked directly. Local
# ``manage.py runserver`` still selects settings_dev before importing ASGI.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_prod")

if os.environ.get("DJANGO_SETTINGS_MODULE") == "core.settings.settings_bench":
    os.environ["BENCH_API_STACK"] = "async"

application = get_asgi_application()
