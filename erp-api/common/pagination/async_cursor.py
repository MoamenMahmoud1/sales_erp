from __future__ import annotations

from rest_framework.exceptions import NotFound
from rest_framework.pagination import Cursor, CursorPagination
from rest_framework.response import Response
from rest_framework.utils.urls import replace_query_param

from common.services.perf_timing import view_stage


def _reverse_ordering(ordering):
    return tuple(
        item[1:] if item.startswith("-") else "-" + item
        for item in ordering
    )


class AsyncCursorPagination(CursorPagination):
    """Cursor pagination that evaluates the queryset without a sync DB hop."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    ordering = "-created_at"
    offset_cutoff = 1000

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
            results = [obj async for obj in queryset[offset : offset + self.page_size + 1]]

        self.page = results[: self.page_size]
        self.has_following_position = len(results) > len(self.page)
        self.following_position = (
            self._get_position_from_instance(results[-1], self.ordering)
            if self.has_following_position
            else None
        )

        if self.page:
            self.first_position = self._get_position_from_instance(
                self.page[0], self.ordering
            )
            self.last_position = self._get_position_from_instance(
                self.page[-1], self.ordering
            )
        else:
            self.first_position = None
            self.last_position = None

        self.has_next = self.has_following_position
        self.has_previous = self.cursor is not None
        self.next_position = self.following_position
        self.previous_position = current_position
        return self.page

    def get_next_link(self):
        if not self.has_next:
            return None

        offset = self.page_size
        position = self.next_position
        cursor = Cursor(offset=offset, reverse=False, position=position)
        return self.encode_cursor(cursor)

    def get_previous_link(self):
        if not self.has_previous:
            return None

        position = self.previous_position
        if position is None:
            return None
        cursor = Cursor(offset=0, reverse=True, position=position)
        return self.encode_cursor(cursor)

    async def get_paginated_response(self, data):
        with view_stage("view.response.paginated"):
            return Response(
                {
                    "next": self.get_next_link(),
                    "previous": self.get_previous_link(),
                    "results": data,
                }
            )
