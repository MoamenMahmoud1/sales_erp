#!/usr/bin/env python3
"""Measure end-to-end HTTP latency without application-side instrumentation."""

from __future__ import annotations

import asyncio
import json
import math
import os
import statistics
import sys
import time
from collections import Counter

import httpx


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    values = sorted(values)
    rank = (len(values) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return values[lower]
    weight = rank - lower
    return values[lower] + (values[upper] - values[lower]) * weight


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    return int(value) if value else default


def env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value else default


async def run_requests(url: str, token: str, requests: int, concurrency: int, timeout_s: float):
    latencies: list[float] = []
    statuses: list[int] = []
    errors: Counter[str] = Counter()
    next_index = 0
    lock = asyncio.Lock()
    limits = httpx.Limits(
        max_connections=concurrency,
        max_keepalive_connections=concurrency,
        keepalive_expiry=30,
    )

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(timeout_s),
        limits=limits,
        http2=False,
        trust_env=False,
    ) as client:
        async def worker() -> None:
            nonlocal next_index
            while True:
                async with lock:
                    if next_index >= requests:
                        return
                    next_index += 1
                started = time.perf_counter()
                try:
                    response = await client.get(
                        url,
                        headers={
                            "Authorization": f"Bearer {token}",
                            "Accept": "application/json",
                        },
                    )
                    response.read()
                    latencies.append((time.perf_counter() - started) * 1000)
                    statuses.append(response.status_code)
                except Exception as exc:  # benchmark must record transport failures
                    latencies.append((time.perf_counter() - started) * 1000)
                    errors[type(exc).__name__] += 1

        await asyncio.gather(*(worker() for _ in range(concurrency)))

    return latencies, statuses, errors


async def main() -> None:
    url = os.environ["BENCH_URL"]
    token = os.environ["BENCH_TOKEN"]
    requests = env_int("BENCH_REQUESTS", 300)
    concurrency = env_int("BENCH_CONCURRENCY", 50)
    warmup = env_int("BENCH_WARMUP", 50)
    timeout_s = env_float("BENCH_TIMEOUT", 10)

    # Warmup is discarded and is never included in the reported measurements.
    await run_requests(url, token, warmup, min(concurrency, warmup), timeout_s)

    started = time.perf_counter()
    latencies, statuses, errors = await run_requests(
        url, token, requests, concurrency, timeout_s
    )
    elapsed = time.perf_counter() - started

    successful = sum(200 <= status < 300 for status in statuses)
    payload = {
        "status": "complete" if len(latencies) == requests and successful == requests else "partial",
        "requests": requests,
        "completed": len(latencies),
        "successful": successful,
        "failed": len(latencies) - successful,
        "error_rate_pct": ((len(latencies) - successful) / len(latencies) * 100) if latencies else None,
        "concurrency": concurrency,
        "warmup_requests": warmup,
        "wall_time_sec": elapsed,
        "rps": len(latencies) / elapsed if elapsed else 0,
        "successful_rps": successful / elapsed if elapsed else 0,
        "latency_mean_ms": statistics.fmean(latencies) if latencies else None,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "latency_min_ms": min(latencies) if latencies else None,
        "latency_max_ms": max(latencies) if latencies else None,
        "status_counts": dict(Counter(map(str, statuses))),
        "errors": dict(errors),
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    if payload["status"] != "complete":
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
