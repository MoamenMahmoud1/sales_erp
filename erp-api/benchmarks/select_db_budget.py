#!/usr/bin/env python3
"""Select a practical database concurrency budget from calibration runs."""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

ROOT = Path(os.environ.get("CALIBRATION_DIR", "benchmark-results/calibration"))
WORKERS = int(os.environ.get("WEB_CONCURRENCY", "4"))


def completion_span(case: dict[str, object]) -> float:
    rows = case.get("request_rows") or []
    ends = [
        float(row["request_end_offset_ms"])
        for row in rows
        if isinstance(row, dict) and row.get("request_end_offset_ms") is not None
    ]
    if ends:
        return max(ends) - min(ends)
    return float(case.get("wall_time_sec", 0)) * 1000.0


def load_cases() -> list[dict[str, object]]:
    cases: list[dict[str, object]] = []
    for path in sorted(ROOT.glob("async-cal-d*.json")):
        case = json.loads(path.read_text(encoding="utf-8"))
        if case.get("status") != "complete" or case.get("failed", 1):
            continue
        per_worker = int(path.stem.removeprefix("async-cal-d"))
        case["per_worker_db_budget"] = per_worker
        case["effective_db_budget"] = per_worker * WORKERS
        case["completion_span_ms"] = completion_span(case)
        cases.append(case)
    if not cases:
        raise SystemExit("no successful calibration cases found")
    return sorted(cases, key=lambda row: int(row["effective_db_budget"]))


def choose(cases: list[dict[str, object]]) -> dict[str, object]:
    # Fixed request count means lower wall time means more of the batch has
    # completed sooner. Stop at the first useful knee: less than 5% wall-time
    # improvement, or a >30% DB-p95 jump, means more concurrency is no longer
    # buying enough completion speed for this workload.
    for previous, current in zip(cases, cases[1:]):
        previous_wall = float(previous.get("wall_time_sec") or 0.0)
        current_wall = float(current.get("wall_time_sec") or 0.0)
        gain_pct = (
            (previous_wall - current_wall) / previous_wall * 100.0
            if previous_wall > 0
            else 0.0
        )

        previous_db_p95 = float(previous.get("db_p95_ms") or 0.0)
        current_db_p95 = float(current.get("db_p95_ms") or 0.0)
        db_growth_pct = (
            (current_db_p95 - previous_db_p95) / previous_db_p95 * 100.0
            if previous_db_p95 > 0
            else 0.0
        )

        if gain_pct < 5.0 or db_growth_pct > 30.0:
            return previous
    return cases[-1]


def main() -> None:
    cases = load_cases()
    selected = choose(cases)

    lines = [
        "| effective D | per-worker D | wall s | RPS | HTTP p95 ms | DB p95 ms | pool p95 ms | completion span ms |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for case in cases:
        marker = " **selected**" if case is selected else ""
        lines.append(
            "| {d}{marker} | {pw} | {wall:.3f} | {rps:.2f} | {p95:.2f} | {db:.2f} | {pool:.2f} | {span:.2f} |".format(
                d=case["effective_db_budget"],
                marker=marker,
                pw=case["per_worker_db_budget"],
                wall=float(case.get("wall_time_sec") or 0),
                rps=float(case.get("successful_rps") or 0),
                p95=float(case.get("p95_ms") or 0),
                db=float(case.get("db_p95_ms") or 0),
                pool=float(case.get("pool_wait_p95_ms") or 0),
                span=float(case["completion_span_ms"]),
            )
        )

    report = [
        "# Async DB budget calibration",
        "",
        f"Workers: `{WORKERS}`",
        "Selection rule: stop at the first step where batch wall-time improvement is <5% or DB p95 grows >30% versus the previous step.",
        "",
        *lines,
        "",
        f"Selected effective DB concurrency: `{selected['effective_db_budget']}`",
        f"Selected per-worker DB concurrency/pool size: `{selected['per_worker_db_budget']}`",
        "",
    ]

    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "calibration-summary.md").write_text("\n".join(report), encoding="utf-8")
    (ROOT / "selected.env").write_text(
        "DB_BUDGET_TOTAL={total}\nDB_BUDGET_PER_WORKER={per_worker}\n".format(
            total=selected["effective_db_budget"],
            per_worker=selected["per_worker_db_budget"],
        ),
        encoding="utf-8",
    )
    print("\n".join(report))


if __name__ == "__main__":
    main()
