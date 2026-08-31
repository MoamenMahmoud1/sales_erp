"""Small, repeatable local HTTP benchmark for the ERP API."""

from __future__ import annotations

import http.client
import json
import os
import statistics
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from urllib.parse import urlsplit

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8000").rstrip("/")
TOKEN_FILE = os.environ.get("TOKEN_FILE", "bench_tokens.json")
TOTAL_REQUESTS = int(os.environ.get("BENCH_REQUESTS", "500"))
WARMUP_REQUESTS = int(os.environ.get("BENCH_WARMUP", "50"))
CONCURRENCIES = tuple(
    int(value)
    for value in os.environ.get("BENCH_CONCURRENCIES", "1,10,25,50,100").split(",")
)
PATHS = {
    "health": "/health/live/",
    "products": "/api/v1/products/products/?page=1&page_size=20",
    "me": "/api/v1/auth/me/",
}


@dataclass(frozen=True)
class Result:
    path_name: str
    concurrency: int
    requests: int
    success: int
    failures: int
    rps: float
    p50_ms: float
    p95_ms: float
    p99_ms: float
    max_ms: float



def percentile(values: list[float], percentile_value: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return float("nan")
    index = (len(ordered) - 1) * percentile_value / 100
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = index - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def request_once(connection: http.client.HTTPConnection, path: str, token: str | None) -> tuple[bool, float, int]:
    headers = {"Connection": "keep-alive"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    started = time.perf_counter_ns()
    try:
        connection.request("GET", path, headers=headers)
        response = connection.getresponse()
        response.read()
        latency_ms = (time.perf_counter_ns() - started) / 1_000_000
        return 200 <= response.status < 300, latency_ms, response.status
    except Exception:
        latency_ms = (time.perf_counter_ns() - started) / 1_000_000
        try:
            connection.close()
        except Exception:
            pass
        return False, latency_ms, 0


def warmup(path: str, tokens: list[str]) -> None:
    host = urlsplit(BASE_URL).netloc
    scheme = urlsplit(BASE_URL).scheme
    if scheme != "http":
        raise RuntimeError("The benchmark currently expects an HTTP BASE_URL")
    connection = http.client.HTTPConnection(host, timeout=10)
    try:
        for index in range(WARMUP_REQUESTS):
            token = tokens[index % len(tokens)] if tokens else None
            ok, _, status = request_once(connection, path, token)
            if not ok:
                raise RuntimeError(f"Warmup failed with status {status}")
    finally:
        connection.close()


def run_level(path_name: str, path: str, concurrency: int, tokens: list[str]) -> Result:
    host = urlsplit(BASE_URL).netloc
    count = max(concurrency, 1)
    request_counts = [TOTAL_REQUESTS // count] * count
    for index in range(TOTAL_REQUESTS % count):
        request_counts[index] += 1

    start_barrier = threading.Barrier(count)

    def worker(worker_index: int) -> tuple[list[float], int]:
        connection = http.client.HTTPConnection(host, timeout=10)
        latencies: list[float] = []
        failures = 0
        token = tokens[worker_index % len(tokens)] if tokens else None
        try:
            start_barrier.wait(timeout=10)
            for _ in range(request_counts[worker_index]):
                ok, latency_ms, _ = request_once(connection, path, token)
                latencies.append(latency_ms)
                failures += int(not ok)
            return latencies, failures
        finally:
            connection.close()

    started = time.perf_counter()
    with ThreadPoolExecutor(max_workers=count) as executor:
        results = list(executor.map(worker, range(count)))
    elapsed = time.perf_counter() - started

    latencies = [latency for worker_latencies, _ in results for latency in worker_latencies]
    failures = sum(worker_failures for _, worker_failures in results)
    success = len(latencies) - failures

    return Result(
        path_name=path_name,
        concurrency=concurrency,
        requests=len(latencies),
        success=success,
        failures=failures,
        rps=len(latencies) / elapsed if elapsed else 0.0,
        p50_ms=percentile(latencies, 50),
        p95_ms=percentile(latencies, 95),
        p99_ms=percentile(latencies, 99),
        max_ms=max(latencies, default=0.0),
    )


def main() -> None:
    with open(TOKEN_FILE, encoding="utf-8") as file:
        tokens = json.load(file)
    if not tokens:
        raise RuntimeError("No benchmark tokens were generated")

    print(f"BASE_URL={BASE_URL}")
    print(f"REQUESTS_PER_LEVEL={TOTAL_REQUESTS}")
    print(f"WARMUP_REQUESTS={WARMUP_REQUESTS}")
    print(f"CONCURRENCIES={CONCURRENCIES}")
    print()

    all_results: list[Result] = []
    for path_name, path in PATHS.items():
        warmup(path, tokens)
        for concurrency in CONCURRENCIES:
            result = run_level(path_name, path, concurrency, tokens)
            all_results.append(result)
            print(
                f"{result.path_name:8} c={result.concurrency:3d} "
                f"ok={result.success:4d} fail={result.failures:3d} "
                f"rps={result.rps:8.2f} "
                f"p50={result.p50_ms:7.2f}ms "
                f"p95={result.p95_ms:7.2f}ms "
                f"p99={result.p99_ms:7.2f}ms "
                f"max={result.max_ms:7.2f}ms"
            )

    with open("benchmark-results.json", "w", encoding="utf-8") as file:
        json.dump([result.__dict__ for result in all_results], file, indent=2)

    if any(result.failures for result in all_results):
        raise SystemExit("Benchmark encountered failed HTTP requests")


if __name__ == "__main__":
    main()
