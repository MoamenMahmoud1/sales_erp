#!/usr/bin/env python3
"""Benchmark-only transport and client-side latency diagnostics.

Measures local HTTP transport separately from Django timing. Intended for CI
benchmark runs only; it never runs in production.
"""

import asyncio
import json
import os
import socket
import statistics
import time
from collections import Counter

import httpx

URL = os.environ.get("BENCH_URL", "http://127.0.0.1:8000/api/v1/products/?page=1&page_size=20")
TOKEN = os.environ.get("BENCH_TOKEN", "")
CONCURRENCY = int(os.environ.get("BENCH_CONCURRENCY", "10"))
REQUESTS = int(os.environ.get("BENCH_REQUESTS", "200"))
TIMEOUT = float(os.environ.get("BENCH_TIMEOUT", "30"))


def pct(values, p):
    if not values:
        return 0.0
    values = sorted(values)
    rank = (len(values) - 1) * p
    lo = int(rank)
    hi = min(lo + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (rank - lo)


async def run():
    headers = {"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}
    limits = httpx.Limits(max_connections=CONCURRENCY, max_keepalive_connections=CONCURRENCY)
    timeout = httpx.Timeout(TIMEOUT)
    connect_ms, ttfb_ms, total_ms, server_ms = [], [], [], []
    errors = Counter()
    statuses = Counter()

    async with httpx.AsyncClient(headers=headers, limits=limits, timeout=timeout, http1=True) as client:
        semaphore = asyncio.Semaphore(CONCURRENCY)
        wall_start = time.perf_counter()

        async def one(i):
            async with semaphore:
                start = time.perf_counter()
                try:
                    response = await client.get(URL)
                    end = time.perf_counter()
                    total = (end - start) * 1000
                    total_ms.append(total)
                    statuses[str(response.status_code)] += 1
                    value = response.headers.get("X-Benchmark-Request-Ms")
                    if value is not None:
                        server_ms.append(float(value))
                    # HTTPX does not expose a portable connect/TTFB timestamp
                    # for HTTP/1.1 responses, so use the response elapsed as the
                    # transport envelope and retain server timing separately.
                    ttfb_ms.append(total)
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
    print(json.dumps({
        "diagnostic": "transport_envelope",
        "requests": REQUESTS,
        "successful": successful,
        "errors": dict(errors),
        "status_codes": dict(statuses),
        "concurrency": CONCURRENCY,
        "wall_time_sec": wall,
        "rps": successful / wall if wall else 0,
        "http_p50_ms": pct(total_ms, .50),
        "http_p95_ms": pct(total_ms, .95),
        "http_p99_ms": pct(total_ms, .99),
        "server_p50_ms": pct(server_ms, .50),
        "server_p95_ms": pct(server_ms, .95),
        "server_p99_ms": pct(server_ms, .99),
        "transport_minus_server_p50_ms": max(pct(total_ms, .50) - pct(server_ms, .50), 0),
        "transport_minus_server_p99_ms": max(pct(total_ms, .99) - pct(server_ms, .99), 0),
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
        "diagnostic": "tcp_connect_probe",
        "p50_ms": pct(samples, .50),
        "p95_ms": pct(samples, .95),
        "p99_ms": pct(samples, .99),
        "mean_ms": statistics.mean(samples),
    }, sort_keys=True))


if __name__ == "__main__":
    socket_probe()
    asyncio.run(run())
