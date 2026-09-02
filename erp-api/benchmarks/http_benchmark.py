#!/usr/bin/env python3
"""End-to-end HTTP benchmark with optional server-stage instrumentation."""

from __future__ import annotations

import asyncio
import json
import math
import os
import statistics
import time
from collections import Counter, defaultdict
from pathlib import Path

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


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


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
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    results: list[dict[str, object]] = []
    server_results: list[dict[str, object]] = []
    queue: asyncio.Queue[int] = asyncio.Queue()

    batch_started = time.perf_counter()
    for index in range(requests):
        await queue.put(index)

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
        async def worker(worker_id: int) -> None:
            while True:
                try:
                    index = queue.get_nowait()
                except asyncio.QueueEmpty:
                    return

                request_started = time.perf_counter()
                row: dict[str, object] = {
                    "request_index": index,
                    "worker_id": worker_id,
                    "request_start_offset_ms": (request_started - batch_started) * 1000,
                }

                try:
                    response = await client.get(
                        url,
                        headers={
                            "Authorization": f"Bearer {token}",
                            "Accept": "application/json",
                        },
                    )
                    response.read()
                    finished = time.perf_counter()
                    request_wire_ms = (finished - request_started) * 1000
                    row.update(
                        {
                            "status_code": response.status_code,
                            "request_wire_ms": request_wire_ms,
                            "request_end_offset_ms": (finished - batch_started) * 1000,
                            "server_total_ms": _header_float(response, "X-Perf-Total-ms"),
                            "server_app_ms": _header_float(response, "X-Perf-App-ms"),
                            "db_admission_ms": _header_float(response, "X-Perf-DB-Admission-ms"),
                            "db_pool_ms": _header_float(response, "X-Perf-DB-Pool-ms"),
                            "db_operation_ms": _header_float(response, "X-Perf-DB-Operation-ms"),
                            "serializer_wait_ms": _header_float(response, "X-Perf-Serializer-Wait-ms"),
                            "serializer_cpu_ms": _header_float(response, "X-Perf-Serializer-CPU-ms"),
                        }
                    )
                    server_results.append(_extract_instrumentation(response))
                except Exception as exc:
                    finished = time.perf_counter()
                    row.update(
                        {
                            "status_code": None,
                            "request_wire_ms": (finished - request_started) * 1000,
                            "request_end_offset_ms": (finished - batch_started) * 1000,
                            "error_type": type(exc).__name__,
                            "error": str(exc),
                        }
                    )

                results.append(row)
                queue.task_done()

                if progress_every and len(results) % progress_every == 0:
                    print(
                        json.dumps(
                            {
                                "phase": "progress",
                                "completed": len(results),
                                "requests": requests,
                            }
                        ),
                        flush=True,
                    )

        await asyncio.gather(*(worker(worker_id) for worker_id in range(concurrency)))

    return results, server_results


def _header_float(response: httpx.Response, name: str) -> float | None:
    value = response.headers.get(name)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _extract_instrumentation(response: httpx.Response) -> dict[str, object]:
    required = {
        "app": "X-Perf-App-ms",
        "db_admission": "X-Perf-DB-Admission-ms",
        "db_pool": "X-Perf-DB-Pool-ms",
        "db_operation": "X-Perf-DB-Operation-ms",
        "serializer_wait": "X-Perf-Serializer-Wait-ms",
        "serializer_cpu": "X-Perf-Serializer-CPU-ms",
    }
    row: dict[str, object] = {"status_code": response.status_code}
    for stage, header in required.items():
        row[stage] = _header_float(response, header)

    for header_name, value in response.headers.items():
        lower = header_name.lower()
        if lower.startswith("x-perf-view-") and lower.endswith("-ms"):
            key = header_name[12:-3].replace("-", ".")
            parsed = _safe_float(value)
            if parsed is not None:
                row[f"view.{key}"] = parsed
        elif lower.startswith("x-perf-sql-"):
            parts = header_name.split("-")
            if lower.endswith("-total-ms"):
                key = "-".join(parts[3:-2]).lower()
                parsed = _safe_float(value)
                if parsed is not None:
                    row[f"sql.{key}.total"] = parsed
            elif lower.endswith("-max-ms"):
                key = "-".join(parts[3:-2]).lower()
                parsed = _safe_float(value)
                if parsed is not None:
                    row[f"sql.{key}.max"] = parsed
        elif lower.startswith("x-perf-fn-") and lower.endswith("-total-ms"):
            name = header_name[10:-9].replace("-", ".")
            parsed = _safe_float(value)
            if parsed is not None:
                row[f"fn.{name}"] = parsed
        elif lower.startswith("x-perf-tx-") and lower.endswith("-total-ms"):
            kind = header_name[10:-9].lower()
            parsed = _safe_float(value)
            if parsed is not None:
                row[f"tx.{kind}"] = parsed
    return row


def _safe_float(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


async def main() -> None:
    url = os.environ["BENCH_URL"]
    token = os.environ["BENCH_TOKEN"]
    requests = env_int("BENCH_REQUESTS", 300)
    concurrency = env_int("BENCH_CONCURRENCY", 50)
    warmup = env_int("BENCH_WARMUP", 50)
    timeout_s = env_float("BENCH_TIMEOUT", 10)
    deadline_s = env_float("BENCH_DEADLINE", 0)
    progress_every = env_int("BENCH_PROGRESS_EVERY", 0)
    benchmark_mode = os.getenv("BENCH_MODE", "unknown")
    pagination_mode = os.getenv("BENCH_PAGINATION", "page")
    detail_path = Path(os.environ["BENCH_DETAIL_PATH"]) if os.getenv("BENCH_DETAIL_PATH") else None
    # Calibration/diagnostic passes explicitly require instrumentation; clean
    # final performance passes deliberately do not.
    require_instrumentation = env_bool("BENCH_REQUIRE_INSTRUMENTATION", False)

    if requests <= 0 or concurrency <= 0:
        raise SystemExit("BENCH_REQUESTS and BENCH_CONCURRENCY must be > 0")

    if warmup > 0:
        await run_requests(url, token, warmup, min(concurrency, warmup), timeout_s)

    batch_started = time.perf_counter()
    request_rows, instrumentation_rows = await run_requests(
        url, token, requests, concurrency, timeout_s, progress_every
    )
    wall_time = time.perf_counter() - batch_started

    request_rows.sort(key=lambda row: int(row["request_index"]))
    successful_rows = [
        row
        for row in request_rows
        if isinstance(row.get("status_code"), int) and 200 <= row["status_code"] < 300
    ]
    latencies = [float(row["request_wire_ms"]) for row in successful_rows]
    errors = Counter(str(row.get("error_type")) for row in request_rows if row.get("error_type"))

    stage_samples: dict[str, list[float]] = defaultdict(list)
    view_stage_samples: dict[str, list[float]] = defaultdict(list)
    sql_samples: dict[str, list[float]] = defaultdict(list)
    function_samples: dict[str, list[float]] = defaultdict(list)
    transaction_samples: dict[str, list[float]] = defaultdict(list)
    instrumented = 0

    for row in instrumentation_rows:
        for stage in ("app", "db_admission", "db_pool", "db_operation", "serializer_wait", "serializer_cpu"):
            value = row.get(stage)
            if isinstance(value, (int, float)):
                stage_samples[stage].append(float(value))
        for key, value in row.items():
            if not isinstance(value, (int, float)) or key == "status_code":
                continue
            if key.startswith("view."):
                view_stage_samples[key[5:]].append(float(value))
            elif key.startswith("sql.") and key.endswith(".total"):
                sql_samples[key[4:]].append(float(value))
            elif key.startswith("fn."):
                function_samples[key[3:]].append(float(value))
            elif key.startswith("tx."):
                transaction_samples[key[3:]].append(float(value))
        if row.get("app") is not None:
            instrumented += 1

    stage_stats = {stage: summarize(values) for stage, values in sorted(stage_samples.items())}
    view_stage_stats = {stage: summarize(values) for stage, values in sorted(view_stage_samples.items())}
    sql_stats = {stage: summarize(values) for stage, values in sorted(sql_samples.items())}
    function_stats = {name: summarize(values) for name, values in sorted(function_samples.items())}
    transaction_stats = {kind: summarize(values) for kind, values in sorted(transaction_samples.items())}

    completed = len(request_rows)
    successful = len(successful_rows)
    failed = completed - successful
    request_complete = completed == requests and successful == requests
    stack_verified = request_complete and (instrumented == successful or not require_instrumentation)

    payload = {
        "phase": "measured",
        "status": "complete" if stack_verified else "partial",
        "mode": benchmark_mode,
        "pagination": pagination_mode,
        "requests": requests,
        "completed": completed,
        "successful": successful,
        "failed": failed,
        "error_rate_pct": (failed / completed * 100) if completed else None,
        "concurrency": concurrency,
        "warmup_requests": warmup,
        "wall_time_sec": wall_time,
        "rps": completed / wall_time if wall_time else 0,
        "successful_rps": successful / wall_time if wall_time else 0,
        "latency_mean_ms": statistics.fmean(latencies) if latencies else None,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "latency_min_ms": min(latencies) if latencies else None,
        "latency_max_ms": max(latencies) if latencies else None,
        "request_start_first_ms": min(
            (float(row["request_start_offset_ms"]) for row in request_rows), default=None
        ),
        "request_start_last_ms": max(
            (float(row["request_start_offset_ms"]) for row in request_rows), default=None
        ),
        "request_detail_file": str(detail_path.name) if detail_path else None,
        "status_counts": dict(Counter(str(row.get("status_code")) for row in request_rows)),
        "errors": dict(errors),
        "server_timing": stage_stats,
        "view_stage_timing": view_stage_stats,
        "sql_timing": sql_stats,
        "function_timing": function_stats,
        "transaction_timing": transaction_stats,
        "server_p50_ms": stage_stats.get("app", {}).get("p50_ms"),
        "server_p95_ms": stage_stats.get("app", {}).get("p95_ms"),
        "server_p99_ms": stage_stats.get("app", {}).get("p99_ms"),
        "db_p50_ms": stage_stats.get("db_operation", {}).get("p50_ms"),
        "db_p95_ms": stage_stats.get("db_operation", {}).get("p95_ms"),
        "db_p99_ms": stage_stats.get("db_operation", {}).get("p99_ms"),
        "pool_wait_p50_ms": stage_stats.get("db_pool", {}).get("p50_ms"),
        "pool_wait_p95_ms": stage_stats.get("db_pool", {}).get("p95_ms"),
        "pool_wait_p99_ms": stage_stats.get("db_pool", {}).get("p99_ms"),
        "db_admission_p50_ms": stage_stats.get("db_admission", {}).get("p50_ms"),
        "db_admission_p95_ms": stage_stats.get("db_admission", {}).get("p95_ms"),
        "db_admission_p99_ms": stage_stats.get("db_admission", {}).get("p99_ms"),
        "serializer_wait_p50_ms": stage_stats.get("serializer_wait", {}).get("p50_ms"),
        "serializer_cpu_p50_ms": stage_stats.get("serializer_cpu", {}).get("p50_ms"),
        "instrumented_responses": instrumented,
        "instrumentation_required": require_instrumentation,
        "stack_verified": stack_verified,
        "deadline_sec": deadline_s,
        "deadline_exceeded": bool(deadline_s and wall_time > deadline_s),
        "request_rows": request_rows,
    }

    if detail_path:
        detail_path.parent.mkdir(parents=True, exist_ok=True)
        detail_path.write_text(
            "\n".join(json.dumps(row, sort_keys=True) for row in request_rows) + "\n",
            encoding="utf-8",
        )

    print(json.dumps(payload, indent=2, sort_keys=True))

    if payload["status"] != "complete":
        raise SystemExit(1)
    if payload["deadline_exceeded"]:
        raise SystemExit(2)


if __name__ == "__main__":
    asyncio.run(main())
