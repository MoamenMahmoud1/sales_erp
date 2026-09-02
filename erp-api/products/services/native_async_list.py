"""Native async Product list implementation for the ASGI hot path.

This path bypasses Django's QuerySet execution for the read-only Products list.
It keeps the existing ProductSerializer/API shape by building unsaved Product
model instances from native async SQL rows and supplying the metric annotations
expected by the serializer.

Write operations and cursor pagination continue to use the Django/ADRF path.
"""

from __future__ import annotations

from math import ceil
from typing import Any

from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.utils.urls import remove_query_param, replace_query_param

from common.services.async_postgres import fetch_all
from common.services.async_serializer import AsyncSerializerService
from common.services.perf_timing import view_stage
from products.models import Product


DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 50

_ORDERING = {
    "name": "p.name ASC",
    "-name": "p.name DESC",
    "purchase_price": "p.purchase_price ASC",
    "-purchase_price": "p.purchase_price DESC",
    "selling_price": "p.selling_price ASC",
    "-selling_price": "p.selling_price DESC",
    "created_at": "p.created_at ASC",
    "-created_at": "p.created_at DESC",
    "updated_at": "p.updated_at ASC",
    "-updated_at": "p.updated_at DESC",
}


def _page_size(request) -> int:
    raw = request.query_params.get("page_size")
    if not raw:
        return DEFAULT_PAGE_SIZE
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_PAGE_SIZE
    return max(1, min(value, MAX_PAGE_SIZE))


def _page_number(request) -> int:
    raw = request.query_params.get("page") or "1"
    if raw == "last":
        raise NotImplementedError("last page is handled by the Django fallback")
    try:
        page = int(raw)
    except (TypeError, ValueError) as exc:
        raise NotFound("Invalid page.") from exc
    if page < 1:
        raise NotFound("Invalid page.")
    return page


def _where_clause(request) -> tuple[str, list[Any]]:
    search = request.query_params.get("search", "").strip()
    if not search:
        return "", []

    terms = [term for term in search.split() if term]
    if not terms:
        return "", []

    clauses = []
    params: list[Any] = []
    for term in terms:
        clauses.append("p.name ILIKE %s")
        params.append(f"%{term}%")
    return "WHERE " + " AND ".join(clauses), params


def _ordering(request) -> str:
    raw = request.query_params.get("ordering", "")
    requested = [part.strip() for part in raw.split(",") if part.strip()]
    selected = [part for part in requested if part in _ORDERING]
    if not selected:
        selected = ["name"]

    expressions = [_ORDERING[item] for item in selected]
    if not any(expr.startswith("p.id ") for expr in expressions):
        descending = selected[-1].startswith("-")
        expressions.append(f"p.id {'DESC' if descending else 'ASC'}")
    return ", ".join(expressions)


class NativeProductListService:
    """Fetch paginated products through a native async PostgreSQL pool."""

    @staticmethod
    async def execute(request) -> tuple[list[Product], int, int, int]:
        page_size = _page_size(request)
        page_number = _page_number(request)
        offset = (page_number - 1) * page_size
        where_sql, params = _where_clause(request)
        order_sql = _ordering(request)

        query = f"""
            WITH filtered AS (
                SELECT
                    p.id,
                    p.name,
                    p.purchase_price,
                    p.selling_price,
                    p.created_at,
                    p.updated_at,
                    COUNT(*) OVER () AS _total_count
                FROM products_product AS p
                {where_sql}
                ORDER BY {order_sql}
                LIMIT %s OFFSET %s
            )
            SELECT
                f.id,
                f.name,
                f.purchase_price,
                f.selling_price,
                f.created_at,
                f.updated_at,
                f._total_count,
                COALESCE(
                    (
                        SELECT SUM(sb.quantity)
                        FROM inventory_stockbalance AS sb
                        WHERE sb.product_id = f.id
                    ),
                    0
                ) AS _total_stock,
                COALESCE(
                    (
                        SELECT SUM(ii.quantity)
                        FROM invoices_invoiceitem AS ii
                        INNER JOIN invoices_invoice AS inv
                            ON inv.id = ii.invoice_id
                        WHERE ii.product_id = f.id
                          AND inv.status IN ('confirmed', 'paid')
                    ),
                    0
                ) AS _sold_quantity
            FROM filtered AS f
        """
        params.extend([page_size, offset])

        with view_stage("view.native_db.product_list"):
            rows = await fetch_all(query, params)

        if not rows:
            if offset == 0:
                return [], 0, page_number, page_size

            count_query = f"SELECT COUNT(*) AS _total_count FROM products_product AS p {where_sql}"
            with view_stage("view.native_db.product_count_fallback"):
                count_rows = await fetch_all(count_query, params[: len(params) - 2])
            total_count = int(count_rows[0]["_total_count"]) if count_rows else 0
            num_pages = ceil(total_count / page_size) if total_count else 1
            if page_number > num_pages:
                raise NotFound("Invalid page.")
            return [], total_count, page_number, page_size

        total_count = int(rows[0]["_total_count"])
        products = []
        for row in rows:
            product = Product(
                id=row["id"],
                name=row["name"],
                purchase_price=row["purchase_price"],
                selling_price=row["selling_price"],
                created_at=row["created_at"],
                updated_at=row["updated_at"],
            )
            product._total_stock = int(row["_total_stock"] or 0)
            product._sold_quantity = int(row["_sold_quantity"] or 0)
            products.append(product)
        return products, total_count, page_number, page_size

    @classmethod
    async def response(cls, request, serializer_class) -> Response:
        products, total_count, page_number, page_size = await cls.execute(request)
        serializer = serializer_class(products, many=True)
        data = await AsyncSerializerService.adata(serializer)
        num_pages = ceil(total_count / page_size) if total_count else 1

        with view_stage("view.native_db.response"):
            next_link = None
            previous_link = None
            if page_number < num_pages:
                next_link = replace_query_param(
                    request.build_absolute_uri(), "page", page_number + 1
                )
            if page_number > 1:
                previous_link = replace_query_param(
                    request.build_absolute_uri(), "page", page_number - 1
                )
                if page_number - 1 == 1:
                    previous_link = remove_query_param(
                        request.build_absolute_uri(), "page"
                    )

            return Response(
                {
                    "count": total_count,
                    "next": next_link,
                    "previous": previous_link,
                    "results": data,
                },
                status=200,
            )


__all__ = ("NativeProductListService",)
