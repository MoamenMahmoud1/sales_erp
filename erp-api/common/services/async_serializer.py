"""Async boundary helpers for synchronous DRF serializer validation."""

from asgiref.sync import sync_to_async


class AsyncSerializerService:
    """Keep synchronous serializer validation outside async API handlers."""

    @staticmethod
    async def ais_valid(serializer, *, raise_exception=False):
        return await sync_to_async(
            serializer.is_valid,
            thread_sensitive=True,
        )(raise_exception=raise_exception)
