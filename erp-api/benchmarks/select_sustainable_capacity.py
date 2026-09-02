#!/usr/bin/env python3
"""Select sustainable capacity from fixed-pool calibration aggregates."""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(os.environ.get("CALIBRATION_DIR", "benchmark-results/calibration"))
WORKERS = int(os.environ.get("WEB_CONCURRENCY", "4"))
MAX_POOL_P95 = float(os.environ.get("MAX_POOL_P95_MS", "50"))
MAX_ERROR_RATE = float(os.environ.get("MAX_ERROR_RATE_PCT", "0"))


def load_cases(prefix: str):
    rows = []
    for d in range(1, 9):
        p = ROOT / f"{prefix}-d{d}.json"
        if not p.exists():
            continue
        c = json.loads(p.read_text())
        c["capacity_per_worker"] = d
        rows.append(c)
    return rows


def healthy(c):
    return (
        c.get("status") == "complete"
        and int(c.get("failed", 0)) == 0
        and float(c.get("error_rate_pct", 0)) <= MAX_ERROR_RATE
        and float(c.get("pool_wait_p95_ms", 0)) <= MAX_POOL_P95
    )


def main():
    prefix = os.environ["CALIBRATION_PREFIX"]
    rows = load_cases(prefix)
    good = [r for r in rows if healthy(r)]
    if not good:
        raise SystemExit(f"No healthy cases for {prefix}")

    # Sustainable operating point: maximize throughput while remaining healthy.
    selected = max(good, key=lambda r: (float(r.get("successful_rps", 0)), -float(r.get("p99_ms", 0))))

    total = int(selected["capacity_per_worker"]) * WORKERS
    lines = [
        f"# {prefix} sustainable capacity",
        "",
        f"Workers: {WORKERS}",
        f"Pool p95 guardrail: <= {MAX_POOL_P95:g} ms", 
        f"Error-rate guardrail: <= {MAX_ERROR_RATE:g}%",
        "",
        "| capacity/worker | total capacity | wall s | RPS | p50 ms | p95 ms | p99 ms | pool p95 ms | admission p95 ms | healthy |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|",
    ]
    for c in rows:
        d = int(c["capacity_per_worker"])
        lines.append(
            f"| {d} | {d*WORKERS} | {float(c.get('wall_time_sec',0)):.3f} | {float(c.get('successful_rps',0)):.2f} | "
            f"{float(c.get('p50_ms',0)):.2f} | {float(c.get('p95_ms',0)):.2f} | {float(c.get('p99_ms',0)):.2f} | "
            f"{float(c.get('pool_wait_p95_ms',0)):.2f} | {float(c.get('db_admission_p95_ms',0)):.2f} | {'yes' if healthy(c) else 'no'}"
        )
    lines += ["", f"Selected capacity/worker: {selected['capacity_per_worker']}", f"Selected total capacity: {total}", ""]
    (ROOT / f"{prefix}-sustainable.md").write_text("\n".join(lines))
    (ROOT / f"{prefix}-selected.env").write_text(
        f"CAPACITY_PER_WORKER={selected['capacity_per_worker']}\nCAPACITY_TOTAL={total}\n"
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
