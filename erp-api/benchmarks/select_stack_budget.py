#!/usr/bin/env python3
"""Choose one sustainable concurrency control per server architecture.

The DB pool is fixed separately. For Sync the control is Gunicorn threads;
for Async the control is the application DB admission gate. A candidate must
be healthy for both pagination modes. Among healthy candidates we maximize the
worst-pagination throughput, then minimize worst tail latency, then minimize
pool pressure and control size.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(os.environ.get("CALIBRATION_ROOT", "benchmark-results/calibration"))
STACK = os.environ.get("STACK", "async")
WORKERS = int(os.environ.get("WEB_CONCURRENCY", "4"))
MAX_POOL_P95_MS = float(os.environ.get("BENCH_MAX_POOL_P95_MS", "50"))
MAX_ERROR_RATE_PCT = float(os.environ.get("BENCH_MAX_ERROR_RATE_PCT", "0"))

CONTROL_NAME = "threads" if STACK == "sync" else "gate"


def load(pagination: str, knob: int) -> dict[str, object]:
    path = ROOT / STACK / pagination / f"{STACK}-cal-d{knob}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def healthy(case: dict[str, object]) -> bool:
    return (
        case.get("status") == "complete"
        and int(case.get("failed") or 0) == 0
        and float(case.get("error_rate_pct") or 0.0) <= MAX_ERROR_RATE_PCT
        and float(case.get("pool_wait_p95_ms") or 0.0) <= MAX_POOL_P95_MS
    )


def main() -> None:
    candidates: list[dict[str, object]] = []

    for knob in range(1, 9):
        page = load("page", knob)
        cursor = load("cursor", knob)
        ok = healthy(page) and healthy(cursor)
        page_rps = float(page.get("successful_rps") or 0.0)
        cursor_rps = float(cursor.get("successful_rps") or 0.0)
        worst_pool = max(
            float(page.get("pool_wait_p95_ms") or 0.0),
            float(cursor.get("pool_wait_p95_ms") or 0.0),
        )
        worst_p95 = max(
            float(page.get("p95_ms") or 0.0),
            float(cursor.get("p95_ms") or 0.0),
        )
        worst_p99 = max(
            float(page.get("p99_ms") or 0.0),
            float(cursor.get("p99_ms") or 0.0),
        )
        candidates.append(
            {
                "knob": knob,
                "healthy": ok,
                "min_rps": min(page_rps, cursor_rps),
                "avg_rps": (page_rps + cursor_rps) / 2,
                "worst_pool_p95": worst_pool,
                "worst_e2e_p95": worst_p95,
                "worst_e2e_p99": worst_p99,
            }
        )

    healthy_cases = [case for case in candidates if case["healthy"]]
    if not healthy_cases:
        raise SystemExit(f"No healthy common {CONTROL_NAME} value for {STACK}")

    # Sustainable objective:
    # 1. Maximize the weaker pagination's throughput.
    # 2. Among similar throughput, prefer the smaller tail.
    # 3. Prefer lower pool pressure.
    # 4. Prefer the smaller control value when the above are tied.
    selected = max(
        healthy_cases,
        key=lambda case: (
            case["min_rps"],
            -case["worst_e2e_p99"],
            -case["worst_pool_p95"],
            -case["knob"],
        ),
    )

    lines = [
        f"# {STACK} sustainable {CONTROL_NAME} selection",
        "",
        f"Workers: `{WORKERS}`",
        "DB pool: fixed at `8` connections per worker during the sweep",
        f"Pool p95 hard guardrail: `<= {MAX_POOL_P95_MS:g} ms` on both paginations",
        f"Error-rate guardrail: `<= {MAX_ERROR_RATE_PCT:g}%`",
        "Selection: one control value must be healthy for both page and cursor; maximize the weaker pagination's throughput, then minimize worst p99/pool pressure.",
        "",
        f"| {CONTROL_NAME} / worker | healthy | min RPS | avg RPS | worst pool p95 ms | worst E2E p95 ms | worst E2E p99 ms |",
        "|---:|:---:|---:|---:|---:|---:|---:|",
    ]

    for case in candidates:
        marker = " **selected**" if case is selected else ""
        lines.append(
            f"| {case['knob']}{marker} | {'yes' if case['healthy'] else 'no'} | "
            f"{case['min_rps']:.2f} | {case['avg_rps']:.2f} | "
            f"{case['worst_pool_p95']:.2f} | {case['worst_e2e_p95']:.2f} | "
            f"{case['worst_e2e_p99']:.2f} |"
        )

    lines += [
        "",
        f"Selected {CONTROL_NAME} per worker: `{selected['knob']}`",
        f"Selected total {CONTROL_NAME}: `{selected['knob'] * WORKERS}`",
    ]

    out = ROOT / STACK / "selected-stack-budget.md"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    # Keep legacy variable names so the workflow can consume the same result,
    # while also exposing the architecture-specific names for human-readable use.
    (ROOT / STACK / "selected-stack-budget.env").write_text(
        f"STACK_CONTROL={CONTROL_NAME}\nCONTROL_PER_WORKER={selected['knob']}\nCONTROL_TOTAL={selected['knob'] * WORKERS}\nDB_BUDGET_PER_WORKER={selected['knob']}\nDB_BUDGET_TOTAL={selected['knob'] * WORKERS}\n",
        encoding="utf-8",
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
