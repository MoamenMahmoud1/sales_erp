#!/usr/bin/env python3
"""Choose one conservative DB budget that is healthy for both paginations."""

from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(os.environ.get("CALIBRATION_ROOT", "benchmark-results/calibration"))
STACK = os.environ.get("STACK", "async")
WORKERS = int(os.environ.get("WEB_CONCURRENCY", "4"))
MAX_POOL_P95_MS = float(os.environ.get("BENCH_MAX_POOL_P95_MS", "50"))
MAX_ERROR_RATE_PCT = float(os.environ.get("BENCH_MAX_ERROR_RATE_PCT", "0"))


def load(pagination: str, d: int) -> dict[str, object]:
    path = ROOT / STACK / pagination / f"{STACK}-cal-d{d}.json"
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
    for d in range(1, 9):
        page = load("page", d)
        cursor = load("cursor", d)
        ok = healthy(page) and healthy(cursor)
        avg_wall = (float(page.get("wall_time_sec") or 0) + float(cursor.get("wall_time_sec") or 0)) / 2
        avg_rps = (float(page.get("successful_rps") or 0) + float(cursor.get("successful_rps") or 0)) / 2
        worst_pool = max(
            float(page.get("pool_wait_p95_ms") or 0),
            float(cursor.get("pool_wait_p95_ms") or 0),
        )
        worst_p99 = max(
            float(page.get("p99_ms") or 0),
            float(cursor.get("p99_ms") or 0),
        )
        candidates.append({
            "d": d,
            "healthy": ok,
            "avg_wall": avg_wall,
            "avg_rps": avg_rps,
            "worst_pool_p95": worst_pool,
            "worst_e2e_p99": worst_p99,
        })

    healthy_cases = [case for case in candidates if case["healthy"]]
    if not healthy_cases:
        raise SystemExit(f"No healthy common D for {STACK}")

    selected = min(healthy_cases, key=lambda case: (case["avg_wall"], -case["d"]))

    lines = [
        f"# {STACK} sustainable DB budget",
        "",
        f"Workers: `{WORKERS}`",
        f"Pool p95 guardrail: `<= {MAX_POOL_P95_MS:g} ms` on every pagination and every repeat aggregate",
        f"Error-rate guardrail: `<= {MAX_ERROR_RATE_PCT:g}%`",
        "Selection: one D must be healthy for both page and cursor; among those, minimize average batch wall time.",
        "",
        "| D / worker | healthy | avg wall s | avg RPS | worst pool p95 ms | worst E2E p99 ms |",
        "|---:|:---:|---:|---:|---:|---:|",
    ]
    for case in candidates:
        marker = " **selected**" if case is selected else ""
        lines.append(
            f"| {case['d']}{marker} | {'yes' if case['healthy'] else 'no'} | "
            f"{case['avg_wall']:.3f} | {case['avg_rps']:.2f} | "
            f"{case['worst_pool_p95']:.2f} | {case['worst_e2e_p99']:.2f} |"
        )

    lines += [
        "",
        f"Selected per-worker D: `{selected['d']}`",
        f"Selected total DB concurrency across workers: `{selected['d'] * WORKERS}`",
    ]

    out = ROOT / STACK / "selected-stack-budget.md"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    (ROOT / STACK / "selected-stack-budget.env").write_text(
        f"DB_BUDGET_PER_WORKER={selected['d']}\nDB_BUDGET_TOTAL={selected['d'] * WORKERS}\n",
        encoding="utf-8",
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
