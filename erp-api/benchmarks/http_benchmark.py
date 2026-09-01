#!/usr/bin/env python3
"""Run a fixed-concurrency HTTP benchmark with runtime stack validation."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import os
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
    error_detail: str | None = None
    server_ms: float | None = None
    db_ms: float | None = None
    pool_wait_ms: float | None = None
    db_queries: float | None = None
    stack: str | None = None
    router: str | None = None
    handler: str | None = None
    async_callable: str | None = None
    async_handler: str | None = None
    view_class: str | None = None
    event_loop: str | None = None
    async_orm_ops: str | None = None
    serializer_path: str | None = None


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


def mean(values: list[float]) -> float | None:
    return statistics.fmean(values) if values else None


def _headers(lines: list[bytes]) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in lines[1:]:
        if b":" in line:
            key, value = line.split(b":", 1)
            result[key.decode("ascii", "ignore").lower()] = value.strip().decode(
                "ascii", "ignore"
            )
    return result


def _validate_stack(headers: dict[str, str], expected: dict[str, str | None]) -> str | None:
    checks = {
        "stack": headers.get("x-benchmark-stack"),
        "router": headers.get("x-benchmark-router"),
        "handler": headers.get("x-benchmark-handler"),
        "async_callable": headers.get("x-benchmark-async-callable"),
        "async_handler": headers.get("x-benchmark-async-handler"),
        "event_loop": headers.get("x-benchmark-event-loop"),
    }
    for key, expected_value in expected.items():
        if expected_value is None:
            continue
        actual = checks.get(key)
        if actual != expected_value:
            return f"{key}:expected={expected_value!r},actual={actual!r}"

    if expected.get("stack") == "async":
        ops = set(filter(None, headers.get("x-benchmark-async-orm-ops", "").split(",")))
        missing = {"acount", "async_iter"} - ops
        if missing:
            return f"async_orm_ops_missing={sorted(missing)!r}"

    return None


async def request_once(
    host: str,
    port: int,
    path: str,
    authorization: str,
    timeout_s: float,
    expected: dict[str, str | None],
) -> Result:
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

            headers = _headers(header_lines)
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

            stack_error = _validate_stack(headers, expected)
            return Result(
                latency_s=time.perf_counter() - started,
                status=status,
                error="stack_mismatch" if stack_error else None,
                error_detail=stack_error,
                server_ms=_float_header(headers.get("x-benchmark-request-ms")),
                db_ms=_float_header(headers.get("x-benchmark-db-ms")),
                pool_wait_ms=_float_header(headers.get("x-benchmark-pool-wait-ms")),
                db_queries=_float_header(headers.get("x-benchmark-db-queries")),
                stack=headers.get("x-benchmark-stack"),
                router=headers.get("x-benchmark-router"),
                handler=headers.get("x-benchmark-handler"),
                async_callable=headers.get("x-benchmark-async-callable"),
                async_handler=headers.get("x-benchmark-async-handler"),
                view_class=headers.get("x-benchmark-view-class"),
                event_loop=headers.get("x-benchmark-event-loop"),
                async_orm_ops=headers.get("x-benchmark-async-orm-ops"),
                serializer_path=headers.get("x-benchmark-serializer-path"),
            )
    except TimeoutError:
        return Result(time.perf_counter() - started, None, "timeout")
    except (OSError, asyncio.IncompleteReadError, ValueError, RuntimeError) as exc:
        return Result(time.perf_counter() - started, None, type(exc).__name__, str(exc))
    finally:
        if writer is not None:
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass


def _float_header(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


async def run_phase(
    *,
    host: str,
    port: int,
    path: str,
    token: str,
    requests: int,
    concurrency: int,
    deadline_s: float,
    request_timeout_s: float,
    expected: dict[str, str | None],
    label: str,
) -> tuple[list[Result], bool]:
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
            result = await request_once(
                host, port, path, token, request_timeout_s, expected
            )
            results.append(result)
            if len(results) - last_report >= 100:
                last_report = len(results)
                print(
                    f"PROGRESS phase={label} completed={last_report}/{requests} "
                    f"elapsed={time.perf_counter() - started:.3f}s",
                    flush=True,
                )

    deadline_exceeded = False
    try:
        async with asyncio.timeout(deadline_s):
            await asyncio.gather(*(worker() for _ in range(concurrency)))
    except TimeoutError:
        deadline_exceeded = True

    return results, deadline_exceeded


def summarize(
    results: list[Result],
    requests: int,
    elapsed: float,
    *,
    concurrency: int,
    warmup_requests: int,
    warmup_deadline_exceeded: bool,
    measured_deadline_exceeded: bool,
    expected: dict[str, str | None],
) -> dict:
    successful = [
        r for r in results if r.status is not None and 200 <= r.status < 300 and r.error is None
    ]
    latencies = [r.latency_s * 1000 for r in results]
    server = [r.server_ms for r in results if r.server_ms is not None]
    db = [r.db_ms for r in results if r.db_ms is not None]
    pool = [r.pool_wait_ms for r in results if r.pool_wait_ms is not None]
    db_queries = [r.db_queries for r in results if r.db_queries is not None]
    status_counts = Counter(str(r.status) for r in results if r.status is not None)
    error_counts = Counter(r.error for r in results if r.error)

    metadata_ok = all(
        r.error not in {"stack_mismatch"}
        and r.stack is not None
        and r.router is not None
        and r.handler is not None
        and r.async_callable is not None
        and r.async_handler is not None
        and r.event_loop is not None
        for r in successful
    )
    if expected.get("stack") == "async":
        metadata_ok = metadata_ok and all(
            set(filter(None, (r.async_orm_ops or "").split(",")))
            >= {"acount", "async_iter"}
            for r in successful
        )

    complete = (
        len(results) == requests
        and len(successful) == requests
        and not measured_deadline_exceeded
        and not warmup_deadline_exceeded
    )

    return {
        "phase": "measured",
        "status": "complete" if complete else "partial",
        "requests": requests,
        "completed": len(results),
        "successful": len(successful),
        "failed": len(results) - len(successful),
        "timeouts": error_counts.get("timeout", 0),
        "error_rate_pct": ((len(results) - len(successful)) / len(results) * 100) if results else None,
        "rps": len(results) / elapsed if elapsed else 0.0,
        "successful_rps": len(successful) / elapsed if elapsed else 0.0,
        "wall_time_sec": elapsed,
        "concurrency": concurrency,
        "warmup_requests": warmup_requests,
        "warmup_deadline_exceeded": warmup_deadline_exceeded,
        "measured_deadline_exceeded": measured_deadline_exceeded,
        "latency_mean_ms": mean(latencies),
        "latency_min_ms": min(latencies) if latencies else None,
        "latency_max_ms": max(latencies) if latencies else None,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "server_mean_ms": mean(server),
        "server_p50_ms": percentile(server, 0.50),
        "server_p95_ms": percentile(server, 0.95),
        "server_p99_ms": percentile(server, 0.99),
        "db_mean_ms": mean(db),
        "db_p50_ms": percentile(db, 0.50),
        "db_p95_ms": percentile(db, 0.95),
        "db_p99_ms": percentile(db, 0.99),
        "pool_wait_mean_ms": mean(pool),
        "pool_wait_p50_ms": percentile(pool, 0.50),
        "pool_wait_p95_ms": percentile(pool, 0.95),
        "pool_wait_p99_ms": percentile(pool, 0.99),
        "db_queries_mean": mean(db_queries),
        "status_counts": dict(status_counts),
        "errors": dict(error_counts),
        "error_details": sorted({r.error_detail for r in results if r.error_detail}),
        "expected_stack": expected.get("stack"),
        "stack_verified": bool(expected.get("stack")) and metadata_ok,
        "observed_stacks": sorted({r.stack for r in results if r.stack}),
        "observed_routers": sorted({r.router for r in results if r.router}),
        "observed_handlers": sorted({r.handler for r in results if r.handler}),
        "observed_async_callables": sorted({r.async_callable for r in results if r.async_callable}),
        "observed_async_handlers": sorted({r.async_handler for r in results if r.async_handler}),
        "observed_event_loops": sorted({r.event_loop for r in results if r.event_loop}),
        "observed_view_classes": sorted({r.view_class for r in results if r.view_class}),
        "observed_async_orm_ops": sorted({r.async_orm_ops for r in results if r.async_orm_ops}),
        "observed_serializer_paths": sorted({r.serializer_path for r in results if r.serializer_path}),
    }


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    return int(value) if value else default


def env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value else default


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("BENCH_URL"))
    parser.add_argument("--token", default=os.getenv("BENCH_TOKEN"))
    parser.add_argument("--requests", type=int, default=env_int("BENCH_REQUESTS", 600))
    parser.add_argument("--warmup", type=int, default=env_int("BENCH_WARMUP", 50))
    parser.add_argument("--concurrency", type=int, default=env_int("BENCH_CONCURRENCY", 1))
    parser.add_argument("--deadline", type=float, default=env_float("BENCH_DEADLINE", 60.0))
    parser.add_argument("--request-timeout", type=float, default=env_float("BENCH_TIMEOUT", 10.0))
    args = parser.parse_args()

    if not args.url:
        parser.error("--url or BENCH_URL is required")
    if not args.token:
        parser.error("--token or BENCH_TOKEN is required")
    if args.requests < 1 or args.warmup < 0:
        parser.error("--requests must be >= 1 and --warmup must be >= 0")
    if args.concurrency < 1:
        parser.error("--concurrency must be >= 1")
    if args.deadline <= 0 or args.request_timeout <= 0:
        parser.error("--deadline and --request-timeout must be > 0")

    expected = {
        "stack": os.getenv("BENCH_EXPECT_STACK"),
        "router": os.getenv("BENCH_EXPECT_ROUTER"),
        "handler": os.getenv("BENCH_EXPECT_HANDLER"),
        "async_callable": os.getenv("BENCH_EXPECT_ASYNC_CALLABLE"),
        "async_handler": os.getenv("BENCH_EXPECT_ASYNC_HANDLER"),
        "event_loop": os.getenv("BENCH_EXPECT_EVENT_LOOP"),
    }

    parsed = urlsplit(args.url)
    if parsed.scheme != "http":
        parser.error("benchmark URL must use http")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or 80
    path = parsed.path or "/"
    if parsed.query:
        path += f"?{parsed.query}"

    if args.warmup:
        warmup_started = time.perf_counter()
        warmup_results, warmup_deadline_exceeded = asyncio.run(
            run_phase(
                host=host,
                port=port,
                path=path,
                token=args.token,
                requests=args.warmup,
                concurrency=args.concurrency,
                deadline_s=max(30.0, args.request_timeout * 2),
                request_timeout_s=args.request_timeout,
                expected=expected,
                label="warmup",
            )
        )
        print(
            f"WARMUP completed={len(warmup_results)}/{args.warmup} "
            f"elapsed={time.perf_counter() - warmup_started:.3f}s",
            flush=True,
        )
    else:
        warmup_deadline_exceeded = False

    started = time.perf_counter()
    results, measured_deadline_exceeded = asyncio.run(
        run_phase(
            host=host,
            port=port,
            path=path,
            token=args.token,
            requests=args.requests,
            concurrency=args.concurrency,
            deadline_s=args.deadline,
            request_timeout_s=args.request_timeout,
            expected=expected,
            label="measured",
        )
    )
    summary = summarize(
        results,
        args.requests,
        time.perf_counter() - started,
        concurrency=args.concurrency,
        warmup_requests=args.warmup,
        warmup_deadline_exceeded=warmup_deadline_exceeded,
        measured_deadline_exceeded=measured_deadline_exceeded,
        expected=expected,
    )
    print(json.dumps(summary, sort_keys=True, allow_nan=False))

    if not summary["stack_verified"] or summary["status"] != "complete":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
