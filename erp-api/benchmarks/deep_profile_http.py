#!/usr/bin/env python3
"""Send one isolated profiled request through the real ASGI stack."""

from __future__ import annotations

import os
import sys
import time

import httpx


def main() -> None:
    url = os.environ["BENCH_URL"]
    token = os.environ["BENCH_TOKEN"]
    kind = os.environ.get("DEEP_PROFILE_KIND", "wall")
    if kind not in {"wall", "cpu"}:
        raise SystemExit("DEEP_PROFILE_KIND must be wall or cpu")

    warmup = int(os.environ.get("DEEP_PROFILE_WARMUP", "10"))
    timeout = float(os.environ.get("BENCH_TIMEOUT", "10"))

    with httpx.Client(timeout=httpx.Timeout(timeout), trust_env=False) as client:
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        }
        for _ in range(warmup):
            response = client.get(url, headers=headers)
            response.read()
            if response.status_code != 200:
                raise SystemExit(f"warmup failed: HTTP {response.status_code}")

        started = time.perf_counter()
        response = client.get(
            url,
            headers={**headers, "X-Deep-Profile": kind},
        )
        response.read()
        elapsed_ms = (time.perf_counter() - started) * 1000

        print(f"profile_kind={kind}")
        print(f"status={response.status_code}")
        print(f"http_elapsed_ms={elapsed_ms:.3f}")
        print(f"request_id={response.headers.get('X-Request-Id', '')}")
        print(
            "app_ms="
            f"{response.headers.get('X-Perf-App-ms', '0')} "
            "db_admission_ms="
            f"{response.headers.get('X-Perf-DB-Admission-ms', '0')} "
            "db_pool_ms="
            f"{response.headers.get('X-Perf-DB-Pool-ms', '0')} "
            "db_operation_ms="
            f"{response.headers.get('X-Perf-DB-Operation-ms', '0')} "
            "serializer_cpu_ms="
            f"{response.headers.get('X-Perf-Serializer-CPU-ms', '0')}"
        )

        if response.status_code != 200:
            print(response.text, file=sys.stderr)
            raise SystemExit(1)


if __name__ == "__main__":
    main()
