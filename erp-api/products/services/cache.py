"""Redis-backed response caching for the Products list endpoint."""

from __future__ import annotations

import asyncio
import hashlib
import json
from collections.abc import Mapping
from urllib.parse import urlencode

from django.conf import settings
from django.core.cache import cache
import redis.asyncio as redis


_async_client: redis.Redis | None = None
_async_loop: asyncio.AbstractEventLoop | None = None


def enabled() -> bool:
    return bool(getattr(settings, "PRODUCT_LIST_CACHE_ENABLED", False))


def ttl() -> int:
    return max(int(getattr(settings, "PRODUCT_LIST_CACHE_TTL", 30) or 0), 1)


def make_key(path: str, query_params: Mapping[str, object]) -> str:
    items: list[tuple[str, str]] = []
    for key in sorted(query_params):
        value = query_params[key]
        if hasattr(query_params, "getlist"):
            values = query_params.getlist(key)  # type: ignore[attr-defined]
        else:
            values = [value]
        for item in values:
            items.append((str(key), str(item)))
    raw = f"v1:{path}?{urlencode(items)}".encode()
    digest = hashlib.sha256(raw).hexdigest()
    # Use Django's key builder so django-redis and native redis.asyncio hit the
    # exact same Redis key without crossing the async/sync boundary for I/O.
    return cache.make_key(f"products:list:{digest}")


def _location() -> str:
    try:
        return str(settings.CACHES["default"]["LOCATION"])
    except Exception as exc:  # pragma: no cover - configuration guard
        raise RuntimeError("Redis cache LOCATION is not configured") from exc


def get_sync(key: str) -> object | None:
    if not enabled():
        return None
    raw = cache.get(key)
    if raw is None:
        return None
    if isinstance(raw, bytes):
        return json.loads(raw)
    if isinstance(raw, str):
        return json.loads(raw)
    return raw


def set_sync(key: str, payload: object) -> None:
    if enabled():
        cache.set(key, json.dumps(payload, separators=(",", ":")).encode(), timeout=ttl())


async def _client_for_current_loop() -> redis.Redis:
    global _async_client, _async_loop
    loop = asyncio.get_running_loop()
    if _async_client is None or _async_loop is not loop:
        if _async_client is not None:
            await _async_client.aclose()
        _async_client = redis.from_url(
            _location(),
            decode_responses=False,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        _async_loop = loop
    return _async_client


async def get_async(key: str) -> object | None:
    if not enabled():
        return None
    client = await _client_for_current_loop()
    raw = await client.get(key)
    if raw is None:
        return None
    return json.loads(raw)


async def set_async(key: str, payload: object) -> None:
    if not enabled():
        return
    client = await _client_for_current_loop()
    raw = json.dumps(payload, separators=(",", ":")).encode()
    await client.set(key, raw, ex=ttl())
