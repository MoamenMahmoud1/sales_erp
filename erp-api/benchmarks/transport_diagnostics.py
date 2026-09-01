#!/usr/bin/env python3
"""Benchmark-only transport envelope diagnostics with stack verification."""

import asyncio
import json
import os
import socket
import statistics
import time
from collections import Counter

import httpx

URL = os.environ.get(
    "BENCH_URL",
    "http://127.0.0.1:8000/api/v1/products/?page=1&page_size=20",
)
TOKEN = os.environ.get("BENCH_TOKEN", "")
CONCURRENCY = int(os.environ.get("BENCH_CONCURRENCY", "10"))
REQUESTS = int(os.environ.get("BENCH_REQUESTS", "200"))
TIMEOUT = float(os.environ.get("BENCH_TIMEOUT", "30"))
STACK = os.environ.get("BENCH_EXPECT_STACK") or os.environ.get("BENCH_API_STACK")
EXPECTED = {
    "stack": STACK,
    "router": os.environ.get("BENCH_EXPECT_ROUTER"),
    "handler": os.environ.get("BENCH_EXPECT_HANDLER"),
    "async_callable": os.environ.get("BENCH_EXPECT_ASYNC_CALLABLE"),
    "async_handler": os.environ.get("BENCH_EXPECT_ASYNC_HANDLER"),
    "event_loop": os.environ.get("BENCH_EXPECT_EVENT_LOOP"),
}
if STACK == "async":
    EXPECTED.update({
        "router": EXPECTED["router"] or "adrf",
        "handler": EXPECTED["handler"] or "alist",
        "async_callable": EXPECTED["async_callable"] or "1",
        "async_handler": EXPECTED["async_handler"] or "1",
        "event_loop": EXPECTED["event_loop"] or "1",
    })
elif STACK == "sync":
    EXPECTED.update({
        "router": EXPECTED["router"] or "drf",
        "handler": EXPECTED["handler"] or "list",
        "async_callable": EXPECTED["async_callable"] or "0",
        "async_handler": EXPECTED["async_handler"] or "0",
        "event_loop": EXPECTED["event_loop"] or "0",
    })


def pct(values, p):
    if not values:
        return None
    values = sorted(values)
    rank = (len(values) - 1) * p
    lo = int(rank)
    hi = min(lo + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (rank - lo)


def validate(response):
    actual = {
        "stack": response.headers.get("x-benchmark-stack"),
        "router": response.headers.get("x-benchmark-router"),
        "handler": response.headers.get("x-benchmark-handler"),
        "async_callable": response.headers.get("x-benchmark-async-callable"),
        "async_handler": response.headers.get("x-benchmark-async-handler"),
        "event_loop": response.headers.get("x-benchmark-event-loop"),
    }
    mismatches = [
        f"{key}:expected={expected!r},actual={actual[key]!r}"
        for key, expected in EXPECTED.items()
        if expected is not None and actual[key] != expected
    ]
    if STACK == "async":
        ops = set(filter(None, response.headers.get("x-benchmark-async-orm-ops", "").split(",")))
        missing = {"acount", "async_iter"} - ops
        if missing:
            mismatches.append(f"async_orm_ops_missing={sorted(missing)!r}")
    return actual, mismatches


async def run():
    headers = {"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}
    limits = httpx.Limits(
        max_connections=CONCURRENCY,
        max_keepalive_connections=CONCURRENCY,
    )
    timeout = httpx.Timeout(TIMEOUT)
    total_ms, server_ms, db_ms, pool_ms = [], [], [], []
    errors = Counter()
    statuses = Counter()
    metadata = []

    async with httpx.AsyncClient(
        headers=headers,
        limits=limits,
        timeout=timeout,
        http1=True,
    ) as client:
        semaphore = asyncio.Semaphore(CONCURRENCY)
        wall_start = time.perf_counter()

        async def one(i):
            async with semaphore:
                start = time.perf_counter()
                try:
                    response = await client.get(URL)
                    total = (time.perf_counter() - start) * 1000
                    total_ms.append(total)
                    statuses[str(response.status_code)] += 1
                    actual, mismatches = validate(response)
                    metadata.append(actual)
                    if mismatches:
                        errors["stack_mismatch"] += 1
                    if value := response.headers.get("x-benchmark-request-ms"):
                        server_ms.append(float(value))
                    if value := response.headers.get("x-benchmark-db-ms"):
                        db_ms.append(float(value))
                    if value := response.headers.get("x-benchmark-pool-wait-ms"):
                        pool_ms.append(float(value))
                except httpx.ConnectError:
                    errors["ConnectError"] += 1
                except httpx.ReadError:
                    errors["ReadError"] += 1
                except httpx.TimeoutException:
                    errors["Timeout"] += 1
                except Exception as exc:  # noqa: BLE001
                    errors[type(exc).__name__] += 1

        await asyncio.gather(*(one(i) for i in range(REQUESTS)))
        wall = time.perf_counter() - wall_start

    successful = sum(v for k, v in statuses.items() if k.startswith("2"))
    all_expected = all(
        all(item.get(key) == value for item in metadata)
        for key, value in EXPECTED.items()
        if value is not None
    )
    stack_verified = bool(STACK) and all_expected and not errors.get("stack_mismatch")

    print(json.dumps({
        "phase": "transport",
        "diagnostic": "transport_envelope",
        "requests": REQUESTS,
        "successful": successful,
        "errors": dict(errors),
        "status_codes": dict(statuses),
        "concurrency": CONCURRENCY,
        "wall_time_sec": wall,
        "rps": successful / wall if wall else 0,
        "http_p50_ms": pct(total_ms, 0.50),
        "http_p95_ms": pct(total_ms, 0.95),
        "http_p99_ms": pct(total_ms, 0.99),
        "server_p50_ms": pct(server_ms, 0.50),
        "server_p95_ms": pct(server_ms, 0.95),
        "server_p99_ms": pct(server_ms, 0.99),
        "db_p50_ms": pct(db_ms, 0.50),
        "db_p95_ms": pct(db_ms, 0.95),
        "db_p99_ms": pct(db_ms, 0.99),
        "pool_p50_ms": pct(pool_ms, 0.50),
        "pool_p95_ms": pct(pool_ms, 0.95),
        "pool_p99_ms": pct(pool_ms, 0.99),
        "transport_minus_server_p50_ms": max(pct(total_ms, 0.50) - pct(server_ms, 0.50), 0) if total_ms and server_ms else None,
        "transport_minus_server_p99_ms": max(pct(total_ms, 0.99) - pct(server_ms, 0.99), 0) if total_ms and server_ms else None,
        "expected_stack": STACK,
        "stack_verified": stack_verified,
        "observed_stacks": sorted({item.get("stack") for item in metadata if item.get("stack")}),
        "observed_routers": sorted({item.get("router") for item in metadata if item.get("router")}),
        "observed_handlers": sorted({item.get("handler") for item in metadata if item.get("handler")}),
        "observed_async_callables": sorted({item.get("async_callable") for item in metadata if item.get("async_callable")}),
        "observed_async_handlers": sorted({item.get("async_handler") for item in metadata if item.get("async_handler")}),
        "observed_event_loops": sorted({item.get("event_loop") for item in metadata if item.get("event_loop")}),
    }, sort_keys=True))


def socket_probe():
    host = "127.0.0.1"
    port = 8000
    samples = []
    for _ in range(20):
        start = time.perf_counter()
        sock = socket.create_connection((host, port), timeout=2)
        sock.close()
        samples.append((time.perf_counter() - start) * 1000)
    print(json.dumps({
        "phase": "transport_probe",
        "diagnostic": "tcp_connect_probe",
        "p50_ms": pct(samples, 0.50),
        "p95_ms": pct(samples, 0.95),
        "p99_ms": pct(samples, 0.99),
        "mean_ms": statistics.mean(samples),
    }, sort_keys=True))


if __name__ == "__main__":
    socket_probe()
    asyncio.run(run())
