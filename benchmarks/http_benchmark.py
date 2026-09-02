"""Repeatable local HTTP benchmark for the ERP API.

HTTP metrics are collected from the client. Optional server metrics are collected
from the server process tree when BENCH_SERVER_PID is provided. PostgreSQL
connection metrics are collected when the DB_* environment variables are set.
"""

from __future__ import annotations

import http.client
import json
import os
import statistics
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from urllib.parse import urlsplit

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8000").rstrip("/")
TOKEN_FILE = os.environ.get("TOKEN_FILE", "bench_tokens.json")
TOTAL_REQUESTS = int(os.environ.get("BENCH_REQUESTS", "500"))
WARMUP_REQUESTS = int(os.environ.get("BENCH_WARMUP", "50"))
CONCURRENCIES = tuple(
    int(value)
    for value in os.environ.get("BENCH_CONCURRENCIES", "1,10,25,50,100").split(",")
)
METRIC_INTERVAL = float(os.environ.get("BENCH_METRIC_INTERVAL", "0.25"))
SERVER_PID = int(os.environ["BENCH_SERVER_PID"]) if os.environ.get("BENCH_SERVER_PID") else None
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
    cpu_avg_pct: float | None
    cpu_peak_pct: float | None
    cpu_time_s: float | None
    cpu_time_ms_per_request: float | None
    ram_avg_mb: float | None
    ram_peak_mb: float | None
    ram_mb_per_request: float | None
    ram_mb_per_100_rps: float | None
    os_threads_avg: float | None
    os_threads_peak: int | None
    db_connections_avg: float | None
    db_connections_peak: int | None


@dataclass
class SystemSample:
    timestamp: float
    cpu_pct: float
    cpu_time_s: float
    ram_mb: float
    threads: int


def percentile(values: list[float], percentile_value: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return float("nan")
    index = (len(ordered) - 1) * percentile_value / 100
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = index - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def request_once(
    connection: http.client.HTTPConnection,
    path: str,
    token: str | None,
) -> tuple[bool, float, int]:
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


def _proc_children(pid: int) -> set[int]:
    """Return the process tree rooted at pid using Linux /proc."""
    tree = {pid}
    changed = True
    while changed:
        changed = False
        try:
            entries = os.listdir("/proc")
        except OSError:
            return tree
        for entry in entries:
            if not entry.isdigit():
                continue
            child = int(entry)
            if child in tree:
                continue
            try:
                with open(f"/proc/{child}/stat", encoding="utf-8") as file:
                    stat = file.read()
                rest = stat.rsplit(") ", 1)[1].split()
                ppid = int(rest[1])
            except (OSError, ValueError, IndexError):
                continue
            if ppid in tree:
                tree.add(child)
                changed = True
    return tree


def _proc_stats(pid: int) -> tuple[float, float, int] | None:
    """Return CPU seconds, RSS MB and OS thread count for one process."""
    try:
        with open(f"/proc/{pid}/stat", encoding="utf-8") as file:
            stat = file.read()
        rest = stat.rsplit(") ", 1)[1].split()
        # After comm/state, utime/stime are fields 14/15 in /proc/<pid>/stat.
        cpu_ticks = int(rest[11]) + int(rest[12])
        with open(f"/proc/{pid}/status", encoding="utf-8") as file:
            status = file.read().splitlines()
        values = {line.split(":", 1)[0]: line.split(":", 1)[1].strip() for line in status if ":" in line}
        rss_kb = int(values.get("VmRSS", "0 kB").split()[0])
        threads = int(values.get("Threads", "0"))
        hz = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
        return cpu_ticks / hz, rss_kb / 1024, threads
    except (OSError, ValueError, IndexError):
        return None


def read_server_stats(pid: int) -> tuple[float, float, int] | None:
    if pid is None or os.name != "posix" or not os.path.exists("/proc"):
        return None
    total_cpu = total_ram = 0.0
    total_threads = 0
    found = False
    for process in _proc_children(pid):
        stats = _proc_stats(process)
        if stats is None:
            continue
        cpu_s, ram_mb, threads = stats
        total_cpu += cpu_s
        total_ram += ram_mb
        total_threads += threads
        found = True
    return (total_cpu, total_ram, total_threads) if found else None


class MetricsCollector:
    def __init__(self, server_pid: int | None, interval: float) -> None:
        self.server_pid = server_pid
        self.interval = interval
        self.samples: list[SystemSample] = []
        self.db_samples: list[int] = []
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._started_at = 0.0
        self._baseline_cpu = 0.0

    def start(self) -> None:
        self._started_at = time.perf_counter()
        initial = read_server_stats(self.server_pid)
        self._baseline_cpu = initial[0] if initial else 0.0
        self._thread = threading.Thread(target=self._collect, name="bench-metrics", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=max(1.0, self.interval * 4))

    def _collect(self) -> None:
        while not self._stop.is_set():
            now = time.perf_counter()
            stats = read_server_stats(self.server_pid)
            if stats:
                self.samples.append(
                    SystemSample(
                        timestamp=now,
                        cpu_pct=0.0,
                        cpu_time_s=stats[0],
                        ram_mb=stats[1],
                        threads=stats[2],
                    )
                )
            db_connections = read_db_connections()
            if db_connections is not None:
                self.db_samples.append(db_connections)
            self._stop.wait(self.interval)

    def finalize(self) -> dict[str, float | int | None]:
        if not self.samples:
            return {
                "cpu_avg_pct": None,
                "cpu_peak_pct": None,
                "cpu_time_s": None,
                "ram_avg_mb": None,
                "ram_peak_mb": None,
                "os_threads_avg": None,
                "os_threads_peak": None,
                "db_connections_avg": statistics.fmean(self.db_samples) if self.db_samples else None,
                "db_connections_peak": max(self.db_samples) if self.db_samples else None,
            }

        cpu_count = os.cpu_count() or 1
        first = self.samples[0]
        previous = first
        cpu_percentages: list[float] = []
        for sample in self.samples[1:]:
            wall = sample.timestamp - previous.timestamp
            cpu_delta = sample.cpu_time_s - previous.cpu_time_s
            if wall > 0:
                cpu_percentages.append(max(0.0, cpu_delta / wall / cpu_count * 100))
            previous = sample
        elapsed = max(time.perf_counter() - self._started_at, 0.0)
        last = self.samples[-1]
        cpu_time_s = max(0.0, last.cpu_time_s - self._baseline_cpu)
        return {
            "cpu_avg_pct": statistics.fmean(cpu_percentages) if cpu_percentages else 0.0,
            "cpu_peak_pct": max(cpu_percentages, default=0.0),
            "cpu_time_s": cpu_time_s,
            "ram_avg_mb": statistics.fmean(sample.ram_mb for sample in self.samples),
            "ram_peak_mb": max(sample.ram_mb for sample in self.samples),
            "os_threads_avg": statistics.fmean(sample.threads for sample in self.samples),
            "os_threads_peak": max(sample.threads for sample in self.samples),
            "db_connections_avg": statistics.fmean(self.db_samples) if self.db_samples else None,
            "db_connections_peak": max(self.db_samples) if self.db_samples else None,
        }


def read_db_connections() -> int | None:
    """Read PostgreSQL client connections without changing the application."""
    try:
        import psycopg
    except ImportError:
        return None

    required = ("DB_NAME", "DB_USER", "DB_PASSWORD")
    if any(not os.environ.get(name) for name in required):
        return None

    try:
        with psycopg.connect(
            dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            host=os.environ.get("DB_HOST", "localhost"),
            port=os.environ.get("DB_PORT", "5432"),
            connect_timeout=2,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT count(*) FROM pg_stat_activity "
                    "WHERE datname = current_database() AND backend_type = 'client backend' "
                    "AND pid <> pg_backend_pid()"
                )
                return int(cursor.fetchone()[0])
    except Exception:
        return None


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

    metrics = MetricsCollector(SERVER_PID, METRIC_INTERVAL)
    metrics.start()
    started = time.perf_counter()
    with ThreadPoolExecutor(max_workers=count) as executor:
        results = list(executor.map(worker, range(count)))
    elapsed = time.perf_counter() - started
    metrics.stop()

    latencies = [latency for worker_latencies, _ in results for latency in worker_latencies]
    failures = sum(worker_failures for _, worker_failures in results)
    success = len(latencies) - failures
    system = metrics.finalize()
    cpu_time_s = system["cpu_time_s"]
    rps = len(latencies) / elapsed if elapsed else 0.0

    return Result(
        path_name=path_name,
        concurrency=concurrency,
        requests=len(latencies),
        success=success,
        failures=failures,
        rps=rps,
        p50_ms=percentile(latencies, 50),
        p95_ms=percentile(latencies, 95),
        p99_ms=percentile(latencies, 99),
        max_ms=max(latencies, default=0.0),
        cpu_avg_pct=system["cpu_avg_pct"],
        cpu_peak_pct=system["cpu_peak_pct"],
        cpu_time_s=cpu_time_s,
        cpu_time_ms_per_request=(cpu_time_s * 1000 / len(latencies)) if cpu_time_s is not None and latencies else None,
        ram_avg_mb=system["ram_avg_mb"],
        ram_peak_mb=system["ram_peak_mb"],
        ram_mb_per_request=(system["ram_avg_mb"] / len(latencies)) if system["ram_avg_mb"] is not None and latencies else None,
        ram_mb_per_100_rps=(system["ram_avg_mb"] / rps * 100) if system["ram_avg_mb"] is not None and rps else None,
        os_threads_avg=system["os_threads_avg"],
        os_threads_peak=system["os_threads_peak"],
        db_connections_avg=system["db_connections_avg"],
        db_connections_peak=system["db_connections_peak"],
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
    print(f"SERVER_PID={SERVER_PID or 'not configured'}")
    print(f"DB_METRICS={'enabled' if read_db_connections() is not None else 'disabled'}")
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
                f"cpu={result.cpu_avg_pct if result.cpu_avg_pct is not None else float('nan'):6.2f}% "
                f"cpu_peak={result.cpu_peak_pct if result.cpu_peak_pct is not None else float('nan'):6.2f}% "
                f"ram={result.ram_avg_mb if result.ram_avg_mb is not None else float('nan'):8.2f}MB "
                f"ram_peak={result.ram_peak_mb if result.ram_peak_mb is not None else float('nan'):8.2f}MB "
                f"threads={result.os_threads_peak if result.os_threads_peak is not None else '-':>4} "
                f"db={result.db_connections_peak if result.db_connections_peak is not None else '-':>3}"
            )

    with open("benchmark-results.json", "w", encoding="utf-8") as file:
        json.dump([asdict(result) for result in all_results], file, indent=2, allow_nan=False)

    if any(result.failures for result in all_results):
        raise SystemExit("Benchmark encountered failed HTTP requests")


if __name__ == "__main__":
    main()
