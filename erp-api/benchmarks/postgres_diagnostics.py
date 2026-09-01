#!/usr/bin/env python3
"""Inspect the Product-list query and PostgreSQL state used by benchmarks."""

import json
import os
import sys
from pathlib import Path

ERP_API_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ERP_API_ROOT))
os.chdir(ERP_API_ROOT)
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_bench")

import django

django.setup()

from django.db import connection  # noqa: E402
from products.api.views import ProductViewSet  # noqa: E402


TABLES = (
    "products_product",
    "inventory_stockbalance",
    "invoices_invoice",
    "invoices_invoiceitem",
)


def explain(cursor, sql, params=()):
    # TIMING ON is intentional here: unlike the load benchmark, this diagnostic
    # is a small single-query probe used to attribute time to individual plan
    # nodes/subplans. It must not be confused with the high-concurrency latency.
    cursor.execute(
        "EXPLAIN (ANALYZE, BUFFERS, SETTINGS, WAL, TIMING ON, FORMAT JSON) " + sql,
        params,
    )
    return cursor.fetchone()[0]


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
        payload["settings"] = [
            dict(zip(("name", "setting", "unit"), row)) for row in cursor.fetchall()
        ]

        cursor.execute(
            "SELECT tablename, indexname, indexdef "
            "FROM pg_indexes WHERE tablename = ANY(%s) ORDER BY tablename, indexname",
            [list(TABLES)],
        )
        payload["indexes"] = [
            dict(zip(("tablename", "indexname", "indexdef"), row))
            for row in cursor.fetchall()
        ]

        cursor.execute(
            "SELECT relname, n_live_tup, n_dead_tup, last_analyze, last_autoanalyze "
            "FROM pg_stat_user_tables WHERE relname = ANY(%s) ORDER BY relname",
            [list(TABLES)],
        )
        payload["table_statistics"] = [
            dict(
                zip(
                    ("relname", "n_live_tup", "n_dead_tup", "last_analyze", "last_autoanalyze"),
                    row,
                )
            )
            for row in cursor.fetchall()
        ]

    queryset = ProductViewSet().get_queryset().order_by("name", "pk")[:20]
    sql, params = queryset.query.sql_with_params()
    with connection.cursor() as cursor:
        payload["product_page_sql"] = sql
        payload["product_page_plan"] = explain(cursor, sql, params)
        payload["product_count_plan"] = explain(
            cursor, "SELECT COUNT(*) FROM products_product"
        )

    print(json.dumps(payload, indent=2, default=str))


if __name__ == "__main__":
    main()
