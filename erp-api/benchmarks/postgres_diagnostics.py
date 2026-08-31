import json
import os

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_bench")
django.setup()

from django.db import connection  # noqa: E402
from products.api.views import ProductViewSet  # noqa: E402


TABLES = (
    "products_product",
    "inventory_stockbalance",
    "invoices_invoice",
    "invoices_invoiceitem",
)


def main():
    payload = {}
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT name, setting, unit FROM pg_settings "
            "WHERE name IN ("
            "'server_version','max_connections','shared_buffers','effective_cache_size',"
            "'work_mem','random_page_cost','effective_io_concurrency','jit','track_io_timing'"
            ") ORDER BY name"
        )
        payload["settings"] = [dict(zip(("name", "setting", "unit"), row)) for row in cursor.fetchall()]

        cursor.execute(
            "SELECT tablename, indexname, indexdef "
            "FROM pg_indexes WHERE tablename = ANY(%s) ORDER BY tablename, indexname",
            [list(TABLES)],
        )
        payload["indexes"] = [
            dict(zip(("tablename", "indexname", "indexdef"), row))
            for row in cursor.fetchall()
        ]

    queryset = ProductViewSet().get_queryset().order_by("name", "pk")[:20]
    sql, params = queryset.query.sql_with_params()
    with connection.cursor() as cursor:
        cursor.execute(
            "EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT JSON) " + sql,
            params,
        )
        payload["product_page_plan"] = cursor.fetchone()[0]

        cursor.execute("EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT JSON) SELECT COUNT(*) FROM products_product")
        payload["product_count_plan"] = cursor.fetchone()[0]

    print(json.dumps(payload, indent=2, default=str))


if __name__ == "__main__":
    main()
