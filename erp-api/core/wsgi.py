import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_prod")

if os.environ.get("DJANGO_SETTINGS_MODULE") == "core.settings.settings_bench":
    os.environ["BENCH_API_STACK"] = "sync"

application = get_wsgi_application()
