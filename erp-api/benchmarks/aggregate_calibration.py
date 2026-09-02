#!/usr/bin/env python3
"""Aggregate repeated D calibration runs conservatively.

The benchmark is run multiple times for the same D. Performance statistics use
medians across repeats, while the pool p95 guardrail uses the worst observed
repeat so a single bad run cannot be hidden by averaging it away.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from statistics import median

ROOT = Path(os.environ.get("CALIBRATION_DIR", "benchmark-results/calibration"))
PREFIX = os.environ.get("CALIBRATION_PREFIX", "async-cal")
REPEATS = int(os.environ.get("CALIBRATION_REPEATS", "3"))


def load(name: str, repeat: int) -> dict[str, object]:
    path = ROOT / f"{name}-r{repeat}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def values(cases: list[dict[str, object]], key: str) -> list[float]:
    return [float(case.get(key) or 0.0) for case in cases]


def aggregate(name: str) -> dict[str, object]:
    cases = [load(name, repeat) for repeat in range(1, REPEATS + 1)]
    complete = [case for case in cases if case.get("status") == "complete"]
    if len(complete) != REPEATS:
        status = "partial"
    else:
        status = "complete"

    numeric_keys = (
        "wall_time_sec",
        "successful_rps",
        "p50_ms",
        "p95_ms",
        "p99_ms",
        "server_p95_ms",
        "db_p95_ms",
        "pool_wait_p95_ms",
        "db_admission_p95_ms",
    )
    out: dict[str, object] = {
        "phase": "calibration-aggregate",
        "status": status,
        "mode": cases[0].get("mode"),
        "pagination": cases[0].get("pagination"),
        "concurrency": cases[0].get("concurrency"),
        "requests": cases[0].get("requests"),
        "successful": min(int(case.get("successful") or 0) for case in cases),
        "failed": max(int(case.get("failed") or 0) for case in cases),
        "error_rate_pct": max(float(case.get("error_rate_pct") or 0.0) for case in cases),
        "repeats": REPEATS,
        "repeat_results": cases,
    }

    for key in numeric_keys:
        nums = values(cases, key)
        out[key] = median(nums)
        out[f"{key}_worst"] = max(nums)
        out[f"{key}_best"] = min(nums)

    # Safety guardrail is deliberately conservative: every repeat must keep
    # pool p95 within the configured limit, so canonical pool p95 is the max.
    out["pool_wait_p95_ms"] = max(values(cases, "pool_wait_p95_ms"))
    out["wall_time_sec"] = median(values(cases, "wall_time_sec"))
    out["successful_rps"] = median(values(cases, "successful_rps"))
    out["p50_ms"] = median(values(cases, "p50_ms"))
    out["p95_ms"] = median(values(cases, "p95_ms"))
    out["p99_ms"] = median(values(cases, "p99_ms"))
    out["db_p95_ms"] = median(values(cases, "db_p95_ms"))
    out["db_admission_p95_ms"] = median(values(cases, "db_admission_p95_ms"))

    return out


def main() -> None:
    for d in range(1, 9):
        name = f"{PREFIX}-d{d}"
        cases = [ROOT / f"{name}-r{repeat}.json" for repeat in range(1, REPEATS + 1)]
        if not all(path.exists() for path in cases):
            continue
        aggregate_case = aggregate(name)
        (ROOT / f"{name}.json").write_text(
            json.dumps(aggregate_case, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(
            f"D={d} wall={aggregate_case['wall_time_sec']:.3f}s "
            f"rps={aggregate_case['successful_rps']:.2f} "
            f"p95={aggregate_case['p95_ms']:.2f}ms "
            f"pool_p95={aggregate_case['pool_wait_p95_ms']:.2f}ms "
            f"admission_p95={aggregate_case['db_admission_p95_ms']:.2f}ms"
        )


if __name__ == "__main__":
    main()
