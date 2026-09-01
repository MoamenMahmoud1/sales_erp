"""Async boundaries for synchronous DRF serializer operations."""

from asgiref.sync import sync_to_async


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
        """Serialize already-materialized objects with one executor hop.

        ADRF's generic serializer path crosses sync_to_async once per field and
        once per field representation. For scalar Product rows this is pure
        CPU work and does not need thread-sensitive ORM access, so batch the
        whole page behind a single non-thread-sensitive boundary.
        """
        return await sync_to_async(
            lambda: serializer.data,
            thread_sensitive=False,
        )()
