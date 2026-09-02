#!/usr/bin/env python3
"""End-to-end HTTP benchmark for fair Sync/Async comparisons.

Set BENCH_SERVER_PID to the Gunicorn master PID to collect server CPU/RAM/thread
metrics. Set BENCH_DB_DSN (or PGHOST/PGDATABASE/PGUSER/PGPASSWORD/PGPORT) to
collect PostgreSQL connection metrics. System sampling is disabled when
BENCH_SERVER_PID is absent, keeping a normal client-only benchmark cheap.
"""

from __future__ import annotations

import asyncio
import json
import math
import os
import statistics
import time
from collections import Counter
from pathlib import Path

import httpx


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    rank = (len(ordered) - 1) * p
    lo, hi = math.floor(rank), math.ceil(rank)
    if lo == hi:
        return ordered[lo]
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (rank - lo)


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    return int(value) if value else default


def env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value else default


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    return value.strip().lower() in {"1", "true", "yes", "on"} if value is not None else default


def _read_proc_stat(pid: int) -> tuple[int, int] | None:
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().split()
        return int(fields[13]) + int(fields[14]), int(fields[19])
    except (FileNotFoundError, PermissionError, ValueError, IndexError):
        return None


def _proc_tree(root_pid: int) -> list[int]:
    pids = {root_pid}
    changed = True
    while changed:
        changed = False
        try:
            entries = list(Path("/proc").iterdir())
        except OSError:
            entries = []
        for entry in entries:
            if not entry.name.isdigit():
                continue
            try:
                fields = (entry / "stat").read_text().split()
                pid, parent = int(entry.name), int(fields[3])
            except (FileNotFoundError, PermissionError, ValueError, IndexError):
                continue
            if parent in pids and pid not in pids:
                pids.add(pid)
                changed = True
    return sorted(pids)


def _read_rss_mb(pid: int) -> float | None:
    try:
        for line in Path(f"/proc/{pid}/status").read_text().splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) / 1024.0
    except (FileNotFoundError, PermissionError, ValueError):
        pass
    return None


class ServerSampler:
    """Low-overhead Linux /proc sampler for the Gunicorn process tree."""

    def __init__(self, root_pid: int, interval_s: float = 0.20) -> None:
        self.root_pid = root_pid
        self.interval_s = interval_s
        self.samples: list[dict[str, float | int]] = []
        self._stop = asyncio.Event()
        self._task: asyncio.Task[None] | None = None
        self._hz = os.sysconf(os.sysconf_names["SC_CLK_TCK"])

    async def start(self) -> None:
        self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        self._stop.set()
        if self._task:
            await self._task

    async def _run(self) -> None:
        previous: dict[int, int] = {}
        previous_t = time.perf_counter()
        while not self._stop.is_set():
            now = time.perf_counter()
            elapsed = max(now - previous_t, 1e-6)
            previous_t = now
            pids = _proc_tree(self.root_pid)
            current: dict[int, int] = {}
            rss = 0.0
            threads = 0
            for pid in pids:
                stat = _read_proc_stat(pid)
                if stat:
                    ticks, thread_count = stat
                    current[pid] = ticks
                    threads += thread_count
                rss_mb = _read_rss_mb(pid)
                if rss_mb is not None:
                    rss += rss_mb
            delta_ticks = sum(max(current[pid] - previous.get(pid, current[pid]), 0) for pid in current)
            cpu_seconds = delta_ticks / self._hz
            self.samples.append({
                "cpu_pct": cpu_seconds / elapsed * 100.0,
                "cpu_seconds": cpu_seconds,
                "rss_mb": rss,
                "threads": threads,
                "processes": len(pids),
            })
            previous = current
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                pass

    def summary(self, completed: int, wall_time: float) -> dict[str, object]:
        cpu = [float(s["cpu_pct"]) for s in self.samples]
        rss = [float(s["rss_mb"]) for s in self.samples]
        threads = [int(s["threads"]) for s in self.samples]
        processes = [int(s["processes"]) for s in self.samples]
        cpu_time = sum(float(s["cpu_seconds"]) for s in self.samples)
        rps = completed / wall_time if wall_time else 0.0
        return {
            "enabled": True,
            "samples": len(self.samples),
            "cpu_avg_pct": statistics.fmean(cpu) if cpu else None,
            "cpu_peak_pct": max(cpu) if cpu else None,
            "cpu_time_sec": cpu_time,
            "cpu_time_ms_per_request": cpu_time * 1000 / completed if completed else None,
            "ram_avg_mb": statistics.fmean(rss) if rss else None,
            "ram_peak_mb": max(rss) if rss else None,
            "ram_mb_per_100_rps": statistics.fmean(rss) / rps * 100 if rss and rps else None,
            "os_threads_avg": statistics.fmean(threads) if threads else None,
            "os_threads_peak": max(threads) if threads else None,
            "processes_peak": max(processes) if processes else None,
        }


class DbSampler:
    """Optional PostgreSQL pg_stat_activity sampler."""

    def __init__(self, dsn: str | None, interval_s: float = 0.50) -> None:
        self.dsn = dsn
        self.interval_s = interval_s
        self.samples: list[int] = []
        self._stop = asyncio.Event()
        self._task: asyncio.Task[None] | None = None

    async def start(self) -> None:
        if self.dsn:
            self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        if self._task:
            self._stop.set()
            await self._task

    async def _run(self) -> None:
        try:
            import psycopg
            conn = await psycopg.AsyncConnection.connect(self.dsn, application_name="bench-db-sampler")
        except Exception:
            return
        async with conn:
            while not self._stop.is_set():
                try:
                    async with conn.cursor() as cur:
                        await cur.execute(
                            "SELECT count(*) FROM pg_stat_activity "
                            "WHERE datname = current_database() "
                            "AND application_name <> 'bench-db-sampler'"
                        )
                        row = await cur.fetchone()
                        if row:
                            self.samples.append(int(row[0]))
                except Exception:
                    pass
                try:
                    await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
                except asyncio.TimeoutError:
                    pass

    def summary(self) -> dict[str, object]:
        return {
            "enabled": bool(self.dsn),
            "samples": len(self.samples),
            "connections_avg": statistics.fmean(self.samples) if self.samples else None,
            "connections_peak": max(self.samples) if self.samples else None,
            "connections_min": min(self.samples) if self.samples else None,
        }


def _dsn_from_env() -> str | None:
    if os.getenv("BENCH_DB_DSN"):
        return os.environ["BENCH_DB_DSN"]
    host, db, user = os.getenv("PGHOST"), os.getenv("PGDATABASE"), os.getenv("PGUSER")
    if not all((host, db, user)):
        return None
    parts = [f"host={host}", f"dbname={db}", f"user={user}"]
    for env, key in (("PGPORT", "port"), ("PGPASSWORD", "password")):
        if os.getenv(env):
            parts.append(f"{key}={os.environ[env]}")
    return " ".join(parts)


async def run_requests(
    url: str, token: str, requests: int, concurrency: int,
    client: httpx.AsyncClient, progress_every: int = 0,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    queue: asyncio.Queue[int] = asyncio.Queue()
    started = time.perf_counter()
    for index in range(requests):
        queue.put_nowait(index)

    async def worker(worker_id: int) -> None:
        while True:
            try:
                index = queue.get_nowait()
            except asyncio.QueueEmpty:
                return
            request_started = time.perf_counter()
            row: dict[str, object] = {"request_index": index, "worker_id": worker_id,
                                      "request_start_offset_ms": (request_started - started) * 1000}
            try:
                response = await client.get(
                    url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}
                )
                finished = time.perf_counter()
                row.update({
                    "status_code": response.status_code,
                    "request_wire_ms": (finished - request_started) * 1000,
                    "request_end_offset_ms": (finished - started) * 1000,
                    "server_total_ms": _header_float(response, "X-Perf-Total-ms"),
                    "server_app_ms": _header_float(response, "X-Perf-App-ms"),
                    "db_admission_ms": _header_float(response, "X-Perf-DB-Admission-ms"),
                    "db_pool_ms": _header_float(response, "X-Perf-DB-Pool-ms"),
                    "db_operation_ms": _header_float(response, "X-Perf-DB-Operation-ms"),
                    "serializer_wait_ms": _header_float(response, "X-Perf-Serializer-Wait-ms"),
                    "serializer_cpu_ms": _header_float(response, "X-Perf-Serializer-CPU-ms"),
                })
            except Exception as exc:
                finished = time.perf_counter()
                row.update({"status_code": None, "request_wire_ms": (finished - request_started) * 1000,
                            "request_end_offset_ms": (finished - started) * 1000,
                            "error_type": type(exc).__name__, "error": str(exc)})
            rows.append(row)
            queue.task_done()
            if progress_every and len(rows) % progress_every == 0:
                print(json.dumps({"phase": "progress", "completed": len(rows), "requests": requests}), flush=True)

    await asyncio.gather(*(worker(i) for i in range(concurrency)))
    return rows


def _header_float(response: httpx.Response, name: str) -> float | None:
    value = response.headers.get(name)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


async def main() -> None:
    url, token = os.environ["BENCH_URL"], os.environ["BENCH_TOKEN"]
    requests = env_int("BENCH_REQUESTS", 300)
    concurrency = env_int("BENCH_CONCURRENCY", 50)
    warmup = env_int("BENCH_WARMUP", 50)
    timeout_s = env_float("BENCH_TIMEOUT", 10)
    progress_every = env_int("BENCH_PROGRESS_EVERY", 0)
    mode = os.getenv("BENCH_MODE", "unknown")
    pagination = os.getenv("BENCH_PAGINATION", "page")
    redis_cache = env_bool("BENCH_REDIS_CACHE", False)
    detail_path = Path(os.environ["BENCH_DETAIL_PATH"]) if os.getenv("BENCH_DETAIL_PATH") else None
    if requests <= 0 or concurrency <= 0:
        raise SystemExit("BENCH_REQUESTS and BENCH_CONCURRENCY must be > 0")

    limits = httpx.Limits(max_connections=concurrency, max_keepalive_connections=concurrency, keepalive_expiry=30)
    server_pid = os.getenv("BENCH_SERVER_PID")
    sampler = ServerSampler(int(server_pid), env_float("BENCH_SYSTEM_SAMPLE_INTERVAL", 0.20)) if server_pid else None
    db_sampler = DbSampler(_dsn_from_env(), env_float("BENCH_DB_SAMPLE_INTERVAL", 0.50))

    async with httpx.AsyncClient(timeout=httpx.Timeout(timeout_s), limits=limits, http2=False, trust_env=False) as client:
        warmup_requests = 1 if redis_cache and warmup > 0 else (max(warmup, concurrency) if warmup > 0 else 0)
        if warmup_requests:
            await run_requests(url, token, warmup_requests, 1 if redis_cache else concurrency, client)
        if sampler:
            await sampler.start()
        await db_sampler.start()
        batch_started = time.perf_counter()
        rows = await run_requests(url, token, requests, concurrency, client, progress_every)
        wall_time = time.perf_counter() - batch_started
        if sampler:
            await sampler.stop()
        await db_sampler.stop()

    rows.sort(key=lambda row: int(row["request_index"]))
    successful = [r for r in rows if isinstance(r.get("status_code"), int) and 200 <= int(r["status_code"]) < 300]
    latencies = [float(r["request_wire_ms"]) for r in successful]
    failed = len(rows) - len(successful)
    rps = len(rows) / wall_time if wall_time else 0.0
    errors = Counter(str(r.get("error_type")) for r in rows if r.get("error_type"))
    server_app = [float(r["server_app_ms"]) for r in successful if r.get("server_app_ms") is not None]
    db_operation = [float(r["db_operation_ms"]) for r in successful if r.get("db_operation_ms") is not None]

    payload = {
        "phase": "measured",
        "status": "complete" if len(rows) == requests else "partial",
        "mode": mode,
        "pagination": pagination,
        "redis_product_cache": redis_cache,
        "requests": requests,
        "completed": len(rows),
        "successful": len(successful),
        "failed": failed,
        "error_rate_pct": failed / len(rows) * 100 if rows else None,
        "concurrency": concurrency,
        "wall_time_sec": wall_time,
        "rps": rps,
        "successful_rps": len(successful) / wall_time if wall_time else 0.0,
        "latency_mean_ms": statistics.fmean(latencies) if latencies else None,
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "errors": dict(errors),
        "status_counts": dict(Counter(str(r.get("status_code")) for r in rows)),
        "cpu_memory_threads": sampler.summary(len(rows), wall_time) if sampler else {"enabled": False},
        "db_connections": db_sampler.summary(),
        "server_p50_ms": percentile(server_app, 0.50),
        "server_p95_ms": percentile(server_app, 0.95),
        "server_p99_ms": percentile(server_app, 0.99),
        "db_p50_ms": percentile(db_operation, 0.50),
        "db_p95_ms": percentile(db_operation, 0.95),
        "db_p99_ms": percentile(db_operation, 0.99),
        "request_rows": rows,
    }
    if detail_path:
        detail_path.parent.mkdir(parents=True, exist_ok=True)
        detail_path.write_text("\n".join(json.dumps(r, sort_keys=True) for r in rows) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2, sort_keys=True))
    if len(rows) != requests:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
