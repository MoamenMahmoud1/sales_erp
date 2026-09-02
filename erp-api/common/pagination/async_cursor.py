from __future__ import annotations

from rest_framework.pagination import Cursor, CursorPagination
from rest_framework.response import Response

from common.services.async_db_gate import db_slot
from common.services.perf_timing import db_operation, view_stage


def _reverse_ordering(ordering):
    return tuple(
        item[1:] if item.startswith("-") else "-" + item
        for item in ordering
    )


class AsyncCursorPagination(CursorPagination):
    """Forward/backward cursor pagination with async queryset evaluation."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    ordering = "-pk"
    offset_cutoff = 1000

    def get_ordering(self, request, queryset, view=None):
        # Keep cursor pagination on one unique, indexed ordering. The regular
        # Product endpoint supports arbitrary OrderingFilter fields, but a
        # cursor should remain stable and seekable.
        return (self.ordering,) if isinstance(self.ordering, str) else tuple(self.ordering)

    async def paginate_queryset(self, queryset, request, view=None):
        self.request = request
        self.page_size = self.get_page_size(request)
        if not self.page_size:
            return None

        self.base_url = request.build_absolute_uri()
        self.ordering = self.get_ordering(request, queryset, view)
        self.cursor = self.decode_cursor(request)

        if self.cursor is None:
            offset, reverse, current_position = 0, False, None
        else:
            offset, reverse, current_position = self.cursor

        # Query construction, cursor decoding, and filtering are local work and
        # do not need a database slot. Keep the gate strictly around execution.
        with view_stage("view.pagination.cursor.prepare"):
            queryset = queryset.order_by(
                *_reverse_ordering(self.ordering) if reverse else self.ordering
            )

            if current_position is not None:
                order = self.ordering[0]
                is_reversed = order.startswith("-")
                order_attr = order.lstrip("-")
                if self.cursor.reverse != is_reversed:
                    kwargs = {order_attr + "__lt": current_position}
                else:
                    kwargs = {order_attr + "__gt": current_position}
                queryset = queryset.filter(**kwargs)

        with view_stage("view.pagination.cursor.fetch"):
            async with db_slot():
                with db_operation():
                    results = [
                        obj
                        async for obj in queryset[offset : offset + self.page_size + 1]
                    ]

        # Cursor metadata is pure Python and should never occupy an admission
        # slot while the request is heading toward serialization.
        with view_stage("view.pagination.cursor.page_object"):
            self.page = results[: self.page_size]
            self.has_following_position = len(results) > len(self.page)
            self.following_position = (
                self._get_position_from_instance(results[-1], self.ordering)
                if self.has_following_position
                else None
            )
            self.has_next = self.has_following_position
            self.has_previous = self.cursor is not None
            self.next_position = self.following_position
            self.previous_position = current_position
        return self.page

    def get_next_link(self):
        if not self.has_next:
            return None
        return self.encode_cursor(
            Cursor(offset=self.page_size, reverse=False, position=self.next_position)
        )

    def get_previous_link(self):
        if not self.has_previous or self.previous_position is None:
            return None
        return self.encode_cursor(
            Cursor(offset=0, reverse=True, position=self.previous_position)
        )

    async def get_paginated_response(self, data):
        with view_stage("view.response.paginated"):
            return Response(
                {
                    "next": self.get_next_link(),
                    "previous": self.get_previous_link(),
                    "results": data,
                }
            )
