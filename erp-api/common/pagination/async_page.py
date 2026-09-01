import math

from django.utils.translation import gettext_lazy as _
from rest_framework.exceptions import NotFound
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.utils.urls import remove_query_param, replace_query_param


class AsyncPage:
    """Small page adapter backed by an async-evaluated QuerySet slice."""

    def __init__(self, object_list, number, count, per_page):
        self.object_list = object_list
        self.number = number
        self.paginator = self
        self.count = count
        self.per_page = per_page
        self.num_pages = math.ceil(count / per_page) if count else 1

    def __iter__(self):
        return iter(self.object_list)

    def __len__(self):
        return len(self.object_list)

    def has_next(self):
        return self.number < self.num_pages

    def has_previous(self):
        return self.number > 1

    def next_page_number(self):
        if not self.has_next():
            raise ValueError("No next page")
        return self.number + 1

    def previous_page_number(self):
        if not self.has_previous():
            raise ValueError("No previous page")
        return self.number - 1


class AsyncStandardPagination(PageNumberPagination):
    """Page-number pagination without Django's synchronous Paginator path."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50
    invalid_page_message = _("Invalid page.")

    async def paginate_queryset(self, queryset, request, view=None):
        self.request = request
        page_size = self.get_page_size(request)
        if not page_size:
            return None

        raw_page = request.query_params.get(self.page_query_param) or "1"

        benchmark_ops = getattr(request, "_benchmark_async_orm_operations", None)
        if benchmark_ops is None:
            benchmark_ops = []
            request._benchmark_async_orm_operations = benchmark_ops

        benchmark_ops.append("acount")
        count = await queryset.acount()
        num_pages = math.ceil(count / page_size) if count else 1

        if raw_page in self.last_page_strings:
            page_number = num_pages
        else:
            try:
                page_number = int(raw_page)
            except (TypeError, ValueError) as exc:
                raise NotFound(
                    self.invalid_page_message.format(page_number=raw_page, message=exc)
                ) from exc

        if page_number < 1 or page_number > num_pages:
            raise NotFound(
                self.invalid_page_message.format(
                    page_number=page_number,
                    message=f"valid pages are 1 through {num_pages}",
                )
            )

        start = (page_number - 1) * page_size
        benchmark_ops.append("async_iter")
        objects = [obj async for obj in queryset[start : start + page_size]]
        self.page = AsyncPage(objects, page_number, count, page_size)
        self.display_page_controls = num_pages > 1 and self.template is not None
        return objects

    async def get_paginated_response(self, data):
        return Response(
            {
                "count": self.page.count,
                "next": self.get_next_link(),
                "previous": self.get_previous_link(),
                "results": data,
            }
        )

    def get_next_link(self):
        if not self.page.has_next():
            return None
        url = self.request.build_absolute_uri()
        return replace_query_param(
            url, self.page_query_param, self.page.next_page_number()
        )

    def get_previous_link(self):
        if not self.page.has_previous():
            return None
        url = self.request.build_absolute_uri()
        page_number = self.page.previous_page_number()
        if page_number == 1:
            return remove_query_param(url, self.page_query_param)
        return replace_query_param(url, self.page_query_param, page_number)
