#!/usr/bin/env python3
"""Benchmark exactly N HTTP requests at a fixed concurrency.

Concurrency=1 is the closed-gate case: the next request starts only after the
previous response has completed. Concurrency=N is the open-gate case: all
requests may be in flight together. A global deadline bounds each mode.
"""

from __future__ import annotations

import argparse
import asyncio
import math
import statistics
import time
from collections import Counter
from dataclasses import dataclass
from urllib.parse import urlsplit


@dataclass(slots=True)
class Result:
    latency_s: float
    status: int | None
    error: str | None = None


async def request_once(host: str, port: int, path: str, authorization: str, timeout_s: float) -> Result:
    started = time.perf_counter()
    writer = None
    try:
        async with asyncio.timeout(timeout_s):
            reader, writer = await asyncio.open_connection(host, port)
            request = (
                f"GET {path} HTTP/1.1\r\n"
                f"Host: {host}:{port}\r\n"
                f"Authorization: Bearer {authorization}\r\n"
                "Accept: application/json\r\n"
                "Connection: close\r\n"
                "\r\n"
            ).encode()
            writer.write(request)
            await writer.drain()
            header_bytes = await reader.readuntil(b"\r\n\r\n")
            header_lines = header_bytes[:-4].split(b"\r\n")
            status_line = header_lines[0].decode("ascii", "replace")
            try:
                status = int(status_line.split(" ", 2)[1])
            except (IndexError, ValueError) as exc:
                raise RuntimeError(f"invalid HTTP status line: {status_line!r}") from exc
            headers = {}
            for line in header_lines[1:]:
                if b":" in line:
                    key, value = line.split(b":", 1)
                    headers[key.decode("ascii", "ignore").lower()] = value.strip().decode("ascii", "ignore")
            content_length = headers.get("content-length")
            if content_length is not None:
                remaining = int(content_length)
                while remaining:
                    chunk = await reader.read(min(remaining, 65536))
                    if not chunk:
                        raise RuntimeError("connection closed before full response body")
                    remaining -= len(chunk)
            else:
                while await reader.read(65536):
                    pass
            return Result(time.perf_counter() - started, status)
    except TimeoutError:
        return Result(time.perf_counter() - started, None, "timeout")
    except (OSError, asyncio.IncompleteReadError, ValueError, RuntimeError) as exc:
        return Result(time.perf_counter() - started, None, type(exc).__name__)
    finally:
        if writer is not None:
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass


async def run_benchmark(*, url: str, token: str, requests: int, concurrency: int, deadline_s: float, request_timeout_s: float) -> list[Result]:
    parsed = urlsplit(url)
    if parsed.scheme != "http":
        raise ValueError("benchmark URL must use http")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or 80
    path = parsed.path or "/"
    if parsed.query:
        path += f"?{parsed.query}"
    results: list[Result] = []
    next_index = 0
    lock = asyncio.Lock()
    started = time.perf_counter()
    last_report = 0

    async def worker() -> None:
        nonlocal next_index, last_report
        while True:
            async with lock:
                if next_index >= requests:
                    return
                next_index += 1
            result = await request_once(host, port, path, token, request_timeout_s)
            results.append(result)
            if len(results) - last_report >= 100:
                last_report = len(results)
                print(f"PROGRESS completed={last_report}/{requests} elapsed={time.perf_counter() - started:.3f}s", flush=True)

    async with asyncio.timeout(deadline_s):
        await asyncio.gather(*(worker() for _ in range(concurrency)))
    return results


def percentile(values: list[float], p: float) -> float:
    if not values:
        return math.nan
    values = sorted(values)
    rank = (len(values) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return values[lower]
    weight = rank - lower
    return values[lower] + (values[upper] - values[lower]) * weight


def report(results: list[Result], requests: int, elapsed: float) -> None:
    successful = [r for r in results if r.status is not None and 200 <= r.status < 300]
    latencies = [r.latency_s for r in results]
    status_counts = Counter(r.status for r in results if r.status is not None)
    errors = Counter(r.error for r in results if r.error)
    print(f"requests={requests}")
    print(f"completed={len(results)}")
    print(f"successful_2xx={len(successful)}")
    print(f"failed={len(results) - len(successful)}")
    print(f"rps={len(results) / elapsed:.2f}")
    print(f"successful_rps={len(successful) / elapsed:.2f}")
    print(f"wall_clock_seconds={elapsed:.3f}")
    print(f"latency_mean_ms={statistics.fmean(latencies) * 1000:.3f}")
    print(f"latency_min_ms={min(latencies) * 1000:.3f}")
    print(f"latency_max_ms={max(latencies) * 1000:.3f}")
    print(f"latency_p50_ms={percentile(latencies, 0.50) * 1000:.3f}")
    print(f"latency_p95_ms={percentile(latencies, 0.95) * 1000:.3f}")
    print(f"latency_p99_ms={percentile(latencies, 0.99) * 1000:.3f}")
    print(f"status_counts={dict(status_counts)}")
    if errors:
        print(f"errors={dict(errors)}")
    if len(results) != requests or len(successful) != requests:
        raise SystemExit(2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--requests", type=int, default=600)
    parser.add_argument("--concurrency", type=int, required=True)
    parser.add_argument("--deadline", type=float, default=60.0)
    parser.add_argument("--request-timeout", type=float, default=10.0)
    args = parser.parse_args()
    started = time.perf_counter()
    results = asyncio.run(run_benchmark(url=args.url, token=args.token, requests=args.requests, concurrency=args.concurrency, deadline_s=args.deadline, request_timeout_s=args.request_timeout))
    report(results, args.requests, time.perf_counter() - started)


if __name__ == "__main__":
    main()
