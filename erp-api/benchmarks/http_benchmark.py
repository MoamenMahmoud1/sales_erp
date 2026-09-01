import asyncio
import json
import os
import statistics
import sys
import time
from collections import Counter

import httpx


URL = os.environ.get("BENCH_URL", "http://127.0.0.1:8000/api/v1/products/?page=1&page_size=20")
TOKEN = os.environ.get("BENCH_TOKEN", "")
CONCURRENCY = int(os.environ.get("BENCH_CONCURRENCY", "10"))
REQUESTS = int(os.environ.get("BENCH_REQUESTS", "1000"))
TIMEOUT = float(os.environ.get("BENCH_TIMEOUT", "30"))
DEADLINE = float(os.environ.get("BENCH_DEADLINE", "300"))
WARMUP = int(os.environ.get("BENCH_WARMUP", "100"))
PROGRESS_EVERY = max(1, int(os.environ.get("BENCH_PROGRESS_EVERY", "100")))


def percentile(values, p):
    if not values:
        return 0.0
    values = sorted(values)
    rank = (len(values) - 1) * p
    low = int(rank)
    high = min(low + 1, len(values) - 1)
    return values[low] + (values[high] - values[low]) * (rank - low)


async def run_load(client, total, concurrency):
    semaphore = asyncio.Semaphore(concurrency)
    latencies_ms = []
    server_ms = []
    db_ms = []
    db_queries = []
    statuses = Counter()
    errors = Counter()
    completed = 0
    completed_lock = asyncio.Lock()
    started = time.perf_counter()

    async def one_request(index):
        nonlocal completed
        async with semaphore:
            request_started = time.perf_counter()
            try:
                response = await client.get(URL)
                elapsed = (time.perf_counter() - request_started) * 1000
                latencies_ms.append(elapsed)
                statuses[str(response.status_code)] += 1
                try:
                    server_ms.append(float(response.headers["X-Benchmark-Request-Ms"]))
                    db_ms.append(float(response.headers["X-Benchmark-DB-Ms"]))
                    db_queries.append(int(response.headers["X-Benchmark-DB-Queries"]))
                except (KeyError, ValueError):
                    errors["missing_timing_headers"] += 1
            except asyncio.CancelledError:
                raise
            except httpx.TimeoutException:
                elapsed = (time.perf_counter() - request_started) * 1000
                latencies_ms.append(elapsed)
                errors["timeout"] += 1
            except Exception as exc:  # noqa: BLE001
                elapsed = (time.perf_counter() - request_started) * 1000
                latencies_ms.append(elapsed)
                errors[type(exc).__name__] += 1
            finally:
                async with completed_lock:
                    completed += 1
                    if completed % PROGRESS_EVERY == 0 or completed == total:
                        elapsed = time.perf_counter() - started
                        print(
                            f"PROGRESS completed={completed}/{total} "
                            f"elapsed={elapsed:.3f}s",
                            flush=True,
                        )

    tasks = [asyncio.create_task(one_request(i)) for i in range(total)]
    try:
        await asyncio.wait_for(asyncio.gather(*tasks), timeout=DEADLINE)
    except asyncio.TimeoutError:
        for task in tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        elapsed = time.perf_counter() - started
        print(
            f"DEADLINE_EXCEEDED completed={completed}/{total} "
            f"elapsed={elapsed:.3f}s deadline={DEADLINE:.3f}s",
            flush=True,
        )
        raise

    wall_time = time.perf_counter() - started
    successful = sum(count for status, count in statuses.items() if status.startswith("2"))
    failed_http = total - successful - sum(errors.values())
    failed = failed_http + sum(errors.values())
    rps = successful / wall_time if wall_time else 0.0

    return {
        "requests": total,
        "successful": successful,
        "failed": failed,
        "http_failed": failed_http,
        "errors": dict(errors),
        "error_rate_pct": (failed / total * 100) if total else 0.0,
        "timeouts": errors.get("timeout", 0),
        "wall_time_sec": wall_time,
        "rps": rps,
        "min_ms": min(latencies_ms) if latencies_ms else 0.0,
        "mean_ms": statistics.mean(latencies_ms) if latencies_ms else 0.0,
        "stddev_ms": statistics.stdev(latencies_ms) if len(latencies_ms) > 1 else 0.0,
        "p50_ms": percentile(latencies_ms, 0.50),
        "p75_ms": percentile(latencies_ms, 0.75),
        "p90_ms": percentile(latencies_ms, 0.90),
        "p95_ms": percentile(latencies_ms, 0.95),
        "p99_ms": percentile(latencies_ms, 0.99),
        "max_ms": max(latencies_ms) if latencies_ms else 0.0,
        "server_p50_ms": percentile(server_ms, 0.50),
        "server_p95_ms": percentile(server_ms, 0.95),
        "server_p99_ms": percentile(server_ms, 0.99),
        "db_p50_ms": percentile(db_ms, 0.50),
        "db_p95_ms": percentile(db_ms, 0.95),
        "db_p99_ms": percentile(db_ms, 0.99),
        "db_mean_ms": statistics.mean(db_ms) if db_ms else 0.0,
        "db_queries_mean": statistics.mean(db_queries) if db_queries else 0.0,
        "timed_requests": len(server_ms),
        "status_codes": dict(statuses),
    }


async def main():
    headers = {"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}
    limits = httpx.Limits(
        max_connections=CONCURRENCY,
        max_keepalive_connections=CONCURRENCY,
    )
    timeout = httpx.Timeout(TIMEOUT)

    print(
        json.dumps(
            {
                "phase": "config",
                "requests": REQUESTS,
                "concurrency": CONCURRENCY,
                "request_timeout_sec": TIMEOUT,
                "global_deadline_sec": DEADLINE,
                "warmup_requests": WARMUP,
            },
            sort_keys=True,
        ),
        flush=True,
    )

    async with httpx.AsyncClient(
        headers=headers,
        limits=limits,
        timeout=timeout,
        http1=True,
    ) as client:
        if WARMUP:
            warmup = await run_load(client, WARMUP, CONCURRENCY)
            print(json.dumps({"phase": "warmup", **warmup}, sort_keys=True), flush=True)
        result = await run_load(client, REQUESTS, CONCURRENCY)
        result.update(
            {
                "phase": "measured",
                "concurrency": CONCURRENCY,
                "url": URL,
                "warmup_requests": WARMUP,
                "global_deadline_sec": DEADLINE,
            }
        )
        print(json.dumps(result, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(130)
