"""Opt-in deterministic profiler for one isolated HTTP request.

This module is intentionally not imported unless DEEP_PROFILE_ENABLED is true.
It uses Yappi for coroutine-aware wall/CPU function timings and additionally
captures Django CursorWrapper executions with a nearest-project caller.
"""

from __future__ import annotations

import json
import os
import threading
import time
from collections import defaultdict
from pathlib import Path

import yappi

from django.db.backends.utils import CursorWrapper

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = Path(os.getenv("DEEP_PROFILE_DIR", "/tmp/erp-deep-profile"))

_active_lock = threading.Lock()
_active_session: "DeepProfileSession | None" = None
_patch_lock = threading.Lock()
_patched = False
_original_execute = None
_original_executemany = None


def _is_project_file(filename: str) -> bool:
    try:
        path = Path(filename).resolve()
    except (OSError, RuntimeError):
        return False
    return path == PROJECT_ROOT or PROJECT_ROOT in path.parents


def _caller():
    frame = __import__("sys")._getframe(2)
    while frame is not None:
        filename = frame.f_code.co_filename
        if _is_project_file(filename) and not filename.endswith("deep_profile.py"):
            return {
                "file": str(Path(filename).resolve().relative_to(PROJECT_ROOT)),
                "line": frame.f_lineno,
                "function": frame.f_code.co_qualname,
            }
        frame = frame.f_back
    return {"file": "<external>", "line": 0, "function": "<external>"}


def _normalize_sql(sql: object) -> str:
    return " ".join(str(sql).split())


class DeepProfileSession:
    def __init__(self, kind: str, request_id: str):
        if kind not in {"wall", "cpu"}:
            raise ValueError("profile kind must be wall or cpu")
        self.kind = kind
        self.request_id = request_id
        self.started_ns = time.perf_counter_ns()
        self.sql_samples: list[dict] = []
        self._yappi_started = False

    def start(self) -> None:
        global _active_session
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        with _active_lock:
            if _active_session is not None:
                raise RuntimeError("another deep profile is already active")
            _active_session = self
        _install_sql_patch()
        yappi.clear_stats()
        yappi.set_clock_type(self.kind)
        yappi.start(builtins=False, profile_threads=True)
        self._yappi_started = True

    def stop(self) -> Path:
        global _active_session
        if self._yappi_started:
            yappi.stop()
            self._yappi_started = False

        stats = yappi.get_func_stats()
        functions = []
        for stat in stats:
            # Keep the full Python call graph available, but explicitly label
            # project functions so framework noise cannot be mistaken for app code.
            functions.append(
                {
                    "name": stat.name,
                    "full_name": stat.full_name,
                    "module": stat.module,
                    "lineno": stat.lineno,
                    "ncall": stat.ncall,
                    "ttot_ms": stat.ttot * 1000,
                    "tsub_ms": stat.tsub * 1000,
                    "tavg_ms": stat.tavg * 1000,
                    "project": _is_project_file(stat.module) or stat.module.startswith(
                        ("core", "common", "products", "inventory", "invoices", "payments", "purchases", "customers", "accounts", "suppliers", "coupons", "organization")
                    ),
                    "ctx_name": stat.ctx_name,
                }
            )

        functions.sort(key=lambda x: x["ttot_ms"], reverse=True)

        sql_agg: dict[str, dict] = defaultdict(
            lambda: {
                "count": 0,
                "total_ms": 0.0,
                "max_ms": 0.0,
                "caller": None,
                "sql": None,
            }
        )
        for sample in self.sql_samples:
            key = sample["sql"]
            row = sql_agg[key]
            row["count"] += 1
            row["total_ms"] += sample["duration_ms"]
            row["max_ms"] = max(row["max_ms"], sample["duration_ms"])
            row["caller"] = sample["caller"]
            row["sql"] = key
        sql_rows = list(sql_agg.values())
        for row in sql_rows:
            row["mean_ms"] = row["total_ms"] / row["count"]
        sql_rows.sort(key=lambda x: x["total_ms"], reverse=True)

        duration_ms = (time.perf_counter_ns() - self.started_ns) / 1_000_000
        payload = {
            "profile_kind": self.kind,
            "request_id": self.request_id,
            "duration_ms": duration_ms,
            "functions": functions,
            "sql": sql_rows,
            "sql_samples": self.sql_samples,
            "threads": [
                {
                    "name": stat.name,
                    "id": stat.id,
                    "ttot_ms": stat.ttot * 1000,
                    "sched_count": stat.sched_count,
                }
                for stat in yappi.get_thread_stats()
            ],
        }

        path = OUTPUT_DIR / f"{self.kind}-{self.request_id}.json"
        path.write_text(json.dumps(payload, indent=2, sort_keys=True, default=str))
        yappi.clear_stats()
        with _active_lock:
            _active_session = None
        return path


def profile_requested(request) -> str | None:
    value = request.META.get("HTTP_X_DEEP_PROFILE", "").strip().lower()
    return value if value in {"wall", "cpu"} else None


def start_profile(kind: str, request_id: str) -> DeepProfileSession:
    session = DeepProfileSession(kind, request_id)
    session.start()
    return session


def _record_sql(sql, params, duration_ns, caller) -> None:
    with _active_lock:
        session = _active_session
    if session is None:
        return
    session.sql_samples.append(
        {
            "sql": _normalize_sql(sql),
            "duration_ms": duration_ns / 1_000_000,
            "caller": caller,
            "params_repr": repr(params),
        }
    )


def _execute(self, sql, params=None):
    started = time.perf_counter_ns()
    caller = _caller()
    try:
        return _original_execute(self, sql, params)
    finally:
        _record_sql(sql, params, time.perf_counter_ns() - started, caller)


def _executemany(self, sql, param_list):
    started = time.perf_counter_ns()
    caller = _caller()
    try:
        return _original_executemany(self, sql, param_list)
    finally:
        _record_sql(sql, param_list, time.perf_counter_ns() - started, caller)


def _install_sql_patch() -> None:
    global _patched, _original_execute, _original_executemany
    if _patched:
        return
    with _patch_lock:
        if _patched:
            return
        _original_execute = CursorWrapper.execute
        _original_executemany = CursorWrapper.executemany
        CursorWrapper.execute = _execute
        CursorWrapper.executemany = _executemany
        _patched = True
