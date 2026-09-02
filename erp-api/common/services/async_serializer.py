"""Async boundaries for synchronous DRF serializer operations."""

import time

from asgiref.sync import sync_to_async

from common.services.async_executor import run_sync
from common.services.perf_timing import add_serializer_cpu, add_serializer_wait


class AsyncSerializerService:
    """Keep synchronous serializer work behind explicit async boundaries."""

    @staticmethod
    async def ais_valid(serializer, *, raise_exception=False):
        return await sync_to_async(
            serializer.is_valid,
            thread_sensitive=True,
        )(raise_exception=raise_exception)

    @staticmethod
    async def adata(serializer):
        """Serialize a materialized page and measure executor queueing separately."""
        queued_at = time.perf_counter_ns()
        started_at = 0
        finished_at = 0

        def serialize():
            nonlocal started_at, finished_at
            started_at = time.perf_counter_ns()
            try:
                return serializer.data
            finally:
                finished_at = time.perf_counter_ns()

        data = await run_sync(serialize)

        add_serializer_wait(max(started_at - queued_at, 0))
        add_serializer_cpu(max(finished_at - started_at, 0))
        return data
