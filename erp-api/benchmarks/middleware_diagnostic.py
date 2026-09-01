#!/usr/bin/env python3
"""HTTP diagnostic benchmark for per-middleware latency attribution."""

from __future__ import annotations

import asyncio
import json
import math
import os
import statistics
import time
from collections import defaultdict

import httpx


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    values = sorted(values)
    rank = (len(values) - 1) * p
    lo = math.floor(rank)
    hi = math.ceil(rank)
    if lo == hi:
        return values[lo]
    return values[lo] + (values[hi] - values[lo]) * (rank - lo)


def mean(values: list[float]) -> float | None:
    return statistics.fmean(values) if values else None


def float_header(headers: httpx.Headers, name: str) -> float | None:
    try:
        value = headers.get(name)
        return float(value) if value is not None else None
    except ValueError:
        return None


async def one_request(
    client: httpx.AsyncClient,
    url: str,
    token: str,
    timeout_s: float,
) -> dict:
    started = time.perf_counter()
    try:
        async with asyncio.timeout(timeout_s):
            response = await client.get(
                url,
                headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
            )
            response.read()
            raw = response.headers.get("x-benchmark-middleware", "[]")
            try:
                middleware = json.loads(raw)
            except json.JSONDecodeError:
                middleware = []
            return {
                "latency_ms": (time.perf_counter() - started) * 1000,
                "status": response.status_code,
                "server_ms": float_header(response.headers, "x-benchmark-request-ms"),
                "db_ms": float_header(response.headers, "x-benchmark-db-ms"),
                "pool_ms": float_header(response.headers, "x-benchmark-pool-wait-ms"),
                "gate_ms": float_header(response.headers, "x-benchmark-db-gate-wait-ms"),
                "middleware": middleware,
                "error": None,
            }
    except Exception as exc:
        return {
            "latency_ms": (time.perf_counter() - started) * 1000,
            "status": None,
            "server_ms": None,
            "db_ms": None,
            "pool_ms": None,
            "gate_ms": None,
            "middleware": [],
            "error": f"{type(exc).__name__}: {exc}",
        }


async def run_phase(
    *,
    url: str,
    token: str,
    count: int,
    concurrency: int,
    timeout_s: float,
    deadline_s: float,
) -> tuple[list[dict], bool]:
    limits = httpx.Limits(max_connections=concurrency, max_keepalive_connections=concurrency)
    timeout = httpx.Timeout(timeout_s)
    results: list[dict] = []
    next_index = 0
    lock = asyncio.Lock()
    started = time.perf_counter()

    async with httpx.AsyncClient(timeout=timeout, limits=limits, trust_env=False, http2=False) as client:
        async def worker() -> None:
            nonlocal next_index
            while True:
                async with lock:
                    if next_index >= count:
                        return
                    next_index += 1
                results.append(await one_request(client, url, token, timeout_s))

        deadline = False
        try:
            async with asyncio.timeout(deadline_s):
                await asyncio.gather(*(worker() for _ in range(concurrency)))
        except TimeoutError:
            deadline = True

    return results, deadline


def summarize(results: list[dict], *, case: str, concurrency: int, warmup: int, measured: int, deadline: bool) -> dict:
    successes = [r for r in results if r["status"] and 200 <= r["status"] < 300 and not r["error"]]
    latencies = [r["latency_ms"] for r in results]
    server = [r["server_ms"] for r in results if r["server_ms"] is not None]
    db = [r["db_ms"] for r in results if r["db_ms"] is not None]
    pool = [r["pool_ms"] for r in results if r["pool_ms"] is not None]
    gate = [r["gate_ms"] for r in results if r["gate_ms"] is not None]

    per_middleware: dict[str, dict[str, list[float] | int]] = defaultdict(
        lambda: {"inclusive": [], "exclusive": [], "seen": 0}
    )
    per_request_residual = []
    for result in successes:
        trace = [item for item in result["middleware"] if isinstance(item, dict)]
        for item in trace:
            name = str(item.get("name", ""))
            if not name:
                continue
            per_middleware[name]["inclusive"].append(float(item.get("inclusive_ms", 0.0)))
            per_middleware[name]["exclusive"].append(float(item.get("exclusive_ms", 0.0)))
            per_middleware[name]["seen"] += 1
        exclusive_sum = sum(float(item.get("exclusive_ms", 0.0)) for item in trace)
        if result["server_ms"] is not None:
            per_request_residual.append(max(result["server_ms"] - exclusive_sum, 0.0))

    middleware_summary = {}
    for name, values in per_middleware.items():
        inclusive = values["inclusive"]
        exclusive = values["exclusive"]
        middleware_summary[name] = {
            "seen": values["seen"],
            "coverage_pct": values["seen"] / len(successes) * 100 if successes else 0.0,
            "inclusive_mean_ms": mean(inclusive),
            "inclusive_p50_ms": percentile(inclusive, 0.50),
            "inclusive_p95_ms": percentile(inclusive, 0.95),
            "inclusive_p99_ms": percentile(inclusive, 0.99),
            "exclusive_mean_ms": mean(exclusive),
            "exclusive_p50_ms": percentile(exclusive, 0.50),
            "exclusive_p95_ms": percentile(exclusive, 0.95),
            "exclusive_p99_ms": percentile(exclusive, 0.99),
        }

    status_counts: dict[str, int] = defaultdict(int)
    for result in results:
        status_counts[str(result["status"])] += 1
    errors = defaultdict(int)
    for result in results:
        if result["error"]:
            errors[result["error"].split(":", 1)[0]] += 1

    complete = len(results) == measured and len(successes) == measured and not deadline
    return {
        "phase": "measured",
        "case": case,
        "complete": complete,
        "requests": measured,
        "completed": len(results),
        "successful": len(successes),
        "failed": len(results) - len(successes),
        "concurrency": concurrency,
        "warmup": warmup,
        "deadline_exceeded": deadline,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "server_p50_ms": percentile(server, 0.50),
        "server_p95_ms": percentile(server, 0.95),
        "server_p99_ms": percentile(server, 0.99),
        "db_p50_ms": percentile(db, 0.50),
        "db_p95_ms": percentile(db, 0.95),
        "pool_p50_ms": percentile(pool, 0.50),
        "pool_p95_ms": percentile(pool, 0.95),
        "gate_p50_ms": percentile(gate, 0.50),
        "gate_p95_ms": percentile(gate, 0.95),
        "middleware_residual_p50_ms": percentile(per_request_residual, 0.50),
        "middleware_residual_p95_ms": percentile(per_request_residual, 0.95),
        "middleware": middleware_summary,
        "status_counts": dict(status_counts),
        "errors": dict(errors),
    }


async def main() -> None:
    url = os.getenv("BENCH_URL", "http://127.0.0.1:8000/api/v1/products/?page=1&page_size=20")
    token = os.environ["BENCH_TOKEN"]
    warmup = int(os.getenv("BENCH_WARMUP", "50"))
    measured = int(os.getenv("BENCH_REQUESTS", "300"))
    concurrency = int(os.getenv("BENCH_CONCURRENCY", "50"))
    timeout_s = float(os.getenv("BENCH_TIMEOUT", "10"))
    deadline_s = float(os.getenv("BENCH_DEADLINE", "60"))
    case = os.getenv("BENCH_CASE", "unknown")

    if warmup:
        _, warmup_deadline = await run_phase(
            url=url,
            token=token,
            count=warmup,
            concurrency=min(concurrency, warmup),
            timeout_s=timeout_s,
            deadline_s=deadline_s,
        )
        if warmup_deadline:
            raise SystemExit("warmup deadline exceeded")

    results, measured_deadline = await run_phase(
        url=url,
        token=token,
        count=measured,
        concurrency=concurrency,
        timeout_s=timeout_s,
        deadline_s=deadline_s,
    )
    print(json.dumps(summarize(results, case=case, concurrency=concurrency, warmup=warmup, measured=measured, deadline=measured_deadline), sort_keys=True))


if __name__ == "__main__":
    asyncio.run(main())
