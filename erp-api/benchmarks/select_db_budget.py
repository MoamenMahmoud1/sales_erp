#!/usr/bin/env python3
"""Select the highest sustainable DB concurrency from calibration runs."""

from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(os.environ.get("CALIBRATION_DIR", "benchmark-results/calibration"))
WORKERS = int(os.environ.get("WEB_CONCURRENCY", "4"))
MAX_POOL_P95_MS = float(os.environ.get("BENCH_MAX_POOL_P95_MS", "5"))
MAX_DB_P95_MS = float(os.environ.get("BENCH_MAX_DB_P95_MS", "0"))
MAX_ADMISSION_P95_MS = float(os.environ.get("BENCH_MAX_ADMISSION_P95_MS", "0"))
MAX_ERROR_RATE_PCT = float(os.environ.get("BENCH_MAX_ERROR_RATE_PCT", "0"))


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


def load_cases(prefix: str) -> list[dict[str, object]]:
    cases: list[dict[str, object]] = []
    for path in sorted(ROOT.glob(f"{prefix}-d*.json")):
        case = json.loads(path.read_text(encoding="utf-8"))
        if case.get("status") != "complete" or int(case.get("failed", 1)) != 0:
            continue
        per_worker = int(path.stem.removeprefix(f"{prefix}-d"))
        case["per_worker_db_budget"] = per_worker
        case["effective_db_budget"] = per_worker * WORKERS
        case["completion_span_ms"] = completion_span(case)
        cases.append(case)
    if not cases:
        raise SystemExit(f"no successful calibration cases found for {prefix}")
    return sorted(cases, key=lambda row: int(row["effective_db_budget"]))


def is_healthy(case: dict[str, object]) -> bool:
    if float(case.get("error_rate_pct") or 0.0) > MAX_ERROR_RATE_PCT:
        return False
    pool_p95 = float(case.get("pool_wait_p95_ms") or 0.0)
    if pool_p95 > MAX_POOL_P95_MS:
        return False
    if MAX_DB_P95_MS > 0 and float(case.get("db_p95_ms") or 0.0) > MAX_DB_P95_MS:
        return False
    if MAX_ADMISSION_P95_MS > 0 and float(case.get("db_admission_p95_ms") or 0.0) > MAX_ADMISSION_P95_MS:
        return False
    return True


def choose(cases: list[dict[str, object]]) -> dict[str, object]:
    """Choose max throughput while the DB/pool remains healthy.

    Throughput is the primary objective. A case is eligible only when it has
    zero failures and stays below the configured pool/DB/admission guardrails.
    This means high client concurrency C can queue before the DB instead of
    turning DB-pool waiting into the benchmark's bottleneck.
    """
    healthy = [case for case in cases if is_healthy(case)]
    if not healthy:
        raise SystemExit("no healthy calibration case found")

    # Primary objective: shortest batch completion time (equivalent to highest
    # successful RPS for a fixed request count). Prefer higher D on ties.
    return min(
        healthy,
        key=lambda case: (
            float(case.get("wall_time_sec") or float("inf")),
            -int(case["per_worker_db_budget"]),
        ),
    )


def main() -> None:
    prefix = os.environ.get("CALIBRATION_PREFIX", "async-cal")
    label = os.environ.get("CALIBRATION_LABEL", prefix.removesuffix("-cal").title())
    cases = load_cases(prefix)
    selected = choose(cases)

    lines = [
        "| effective D | per-worker D | wall s | RPS | HTTP p95 ms | DB p95 ms | pool p95 ms | admission p95 ms | completion span ms | healthy |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|",
    ]
    for case in cases:
        healthy = is_healthy(case)
        marker = " **selected**" if case is selected else ""
        lines.append(
            "| {d}{marker} | {pw} | {wall:.3f} | {rps:.2f} | {p95:.2f} | {db:.2f} | {pool:.2f} | {adm:.2f} | {span:.2f} | {healthy} |".format(
                d=case["effective_db_budget"],
                marker=marker,
                pw=case["per_worker_db_budget"],
                wall=float(case.get("wall_time_sec") or 0),
                rps=float(case.get("successful_rps") or 0),
                p95=float(case.get("p95_ms") or 0),
                db=float(case.get("db_p95_ms") or 0),
                pool=float(case.get("pool_wait_p95_ms") or 0),
                adm=float(case.get("db_admission_p95_ms") or 0),
                span=float(case["completion_span_ms"]),
                healthy="yes" if healthy else "no",
            )
        )

    report = [
        f"# {label} DB budget calibration",
        "",
        f"Workers: `{WORKERS}`",
        f"Pool-wait guardrail: `p95 <= {MAX_POOL_P95_MS:g} ms`",
        f"Error-rate guardrail: `<= {MAX_ERROR_RATE_PCT:g}%`",
        "Selection rule: maximize completed throughput (minimum fixed-batch wall time) among healthy cases.",
        "",
        *lines,
        "",
        f"Selected effective DB concurrency: `{selected['effective_db_budget']}`",
        f"Selected per-worker DB concurrency/pool size: `{selected['per_worker_db_budget']}`",
        "",
    ]

    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / f"{prefix}-summary.md").write_text("\n".join(report), encoding="utf-8")
    (ROOT / f"{prefix}-selected.env").write_text(
        "DB_BUDGET_TOTAL={total}\nDB_BUDGET_PER_WORKER={per_worker}\n".format(
            total=selected["effective_db_budget"],
            per_worker=selected["per_worker_db_budget"],
        ),
        encoding="utf-8",
    )
    print("\n".join(report))


if __name__ == "__main__":
    main()
