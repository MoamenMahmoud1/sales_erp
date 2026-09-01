#!/usr/bin/env python3
"""True end-to-end HTTP benchmark with server-side root-cause timings."""

from __future__ import annotations

import asyncio
import json
import math
import os
import statistics
import time
from collections import Counter

import httpx


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    rank = (len(ordered) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[lower]
    weight = rank - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * weight


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    return int(value) if value else default


def env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value else default


def summarize(values: list[float]) -> dict[str, float | int | None]:
    return {
        "count": len(values),
        "mean_ms": statistics.fmean(values) if values else None,
        "p50_ms": percentile(values, 0.50),
        "p95_ms": percentile(values, 0.95),
        "p99_ms": percentile(values, 0.99),
        "max_ms": max(values) if values else None,
    }


async def run_requests(
    url: str,
    token: str,
    requests: int,
    concurrency: int,
    timeout_s: float,
    progress_every: int = 0,
) -> tuple[list[float], list[int], Counter[str], dict[str, list[float]], int]:
    latencies: list[float] = []
    statuses: list[int] = []
    errors: Counter[str] = Counter()
    stage_samples: dict[str, list[float]] = {
        "app": [],
        "db_admission": [],
        "db_pool": [],
        "db_operation": [],
        "serializer_wait": [],
        "serializer_cpu": [],
    }
    instrumented_responses = 0
    next_index = 0
    completed = 0
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
            nonlocal next_index, completed, instrumented_responses
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
                    elapsed_ms = (time.perf_counter() - started) * 1000
                    latencies.append(elapsed_ms)
                    statuses.append(response.status_code)

                    headers = {
                        "app": "X-Perf-App-ms",
                        "db_admission": "X-Perf-DB-Admission-ms",
                        "db_pool": "X-Perf-DB-Pool-ms",
                        "db_operation": "X-Perf-DB-Operation-ms",
                        "serializer_wait": "X-Perf-Serializer-Wait-ms",
                        "serializer_cpu": "X-Perf-Serializer-CPU-ms",
                    }
                    parsed = True
                    for stage, header in headers.items():
                        value = response.headers.get(header)
                        if value is None:
                            parsed = False
                            continue
                        try:
                            stage_samples[stage].append(float(value))
                        except ValueError:
                            parsed = False
                    if parsed:
                        instrumented_responses += 1
                except Exception as exc:
                    latencies.append((time.perf_counter() - started) * 1000)
                    errors[type(exc).__name__] += 1

                async with lock:
                    completed += 1
                    current = completed

                if progress_every and current % progress_every == 0:
                    print(json.dumps({"phase": "progress", "completed": current, "requests": requests}), flush=True)

        await asyncio.gather(*(worker() for _ in range(concurrency)))

    return latencies, statuses, errors, stage_samples, instrumented_responses


async def main() -> None:
    url = os.environ["BENCH_URL"]
    token = os.environ["BENCH_TOKEN"]
    requests = env_int("BENCH_REQUESTS", 300)
    concurrency = env_int("BENCH_CONCURRENCY", 50)
    warmup = env_int("BENCH_WARMUP", 50)
    timeout_s = env_float("BENCH_TIMEOUT", 10)
    deadline_s = env_float("BENCH_DEADLINE", 0)
    progress_every = env_int("BENCH_PROGRESS_EVERY", 0)

    if requests <= 0 or concurrency <= 0:
        raise SystemExit("BENCH_REQUESTS and BENCH_CONCURRENCY must be > 0")

    if warmup > 0:
        await run_requests(url, token, warmup, min(concurrency, warmup), timeout_s)

    started = time.perf_counter()
    latencies, statuses, errors, stage_samples, instrumented = await run_requests(
        url, token, requests, concurrency, timeout_s, progress_every
    )
    elapsed = time.perf_counter() - started

    successful = sum(200 <= status < 300 for status in statuses)
    completed = len(latencies)
    failed = completed - successful
    stage_stats = {stage: summarize(values) for stage, values in stage_samples.items()}

    stack_verified = (
        completed == requests
        and successful == requests
        and instrumented == requests
    )

    payload = {
        "phase": "measured",
        "status": "complete" if stack_verified else "partial",
        "requests": requests,
        "completed": completed,
        "successful": successful,
        "failed": failed,
        "error_rate_pct": (failed / completed * 100) if completed else None,
        "concurrency": concurrency,
        "warmup_requests": warmup,
        "wall_time_sec": elapsed,
        "rps": completed / elapsed if elapsed else 0,
        "successful_rps": successful / elapsed if elapsed else 0,
        "latency_mean_ms": statistics.fmean(latencies) if latencies else None,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "latency_min_ms": min(latencies) if latencies else None,
        "latency_max_ms": max(latencies) if latencies else None,
        "status_counts": dict(Counter(map(str, statuses))),
        "errors": dict(errors),
        "server_timing": stage_stats,
        "server_p50_ms": stage_stats["app"]["p50_ms"],
        "server_p95_ms": stage_stats["app"]["p95_ms"],
        "server_p99_ms": stage_stats["app"]["p99_ms"],
        "db_p50_ms": stage_stats["db_operation"]["p50_ms"],
        "db_p95_ms": stage_stats["db_operation"]["p95_ms"],
        "db_p99_ms": stage_stats["db_operation"]["p99_ms"],
        "pool_wait_p50_ms": stage_stats["db_pool"]["p50_ms"],
        "pool_wait_p95_ms": stage_stats["db_pool"]["p95_ms"],
        "pool_wait_p99_ms": stage_stats["db_pool"]["p99_ms"],
        "db_admission_p50_ms": stage_stats["db_admission"]["p50_ms"],
        "db_admission_p95_ms": stage_stats["db_admission"]["p95_ms"],
        "db_admission_p99_ms": stage_stats["db_admission"]["p99_ms"],
        "serializer_wait_p50_ms": stage_stats["serializer_wait"]["p50_ms"],
        "serializer_cpu_p50_ms": stage_stats["serializer_cpu"]["p50_ms"],
        "instrumented_responses": instrumented,
        "stack_verified": stack_verified,
        "deadline_sec": deadline_s,
        "deadline_exceeded": bool(deadline_s and elapsed > deadline_s),
    }

    print(json.dumps(payload, indent=2, sort_keys=True))

    if payload["status"] != "complete":
        raise SystemExit(1)
    if payload["deadline_exceeded"]:
        raise SystemExit(2)


if __name__ == "__main__":
    asyncio.run(main())
