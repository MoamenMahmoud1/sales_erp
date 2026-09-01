# Performance Optimization Report — Sales ERP

## Executive decision

**Final runtime choice:** keep the Products API fully ASGI/async, use the benchmark-backed **DB admission gate = 4 per worker**, keep the **DB pool max = 8 per worker**, and run the API with a dedicated lean middleware settings module that removes API-irrelevant sync middleware from the hot path.

This is the only configuration change treated as the final selected configuration from the evidence currently available. The SQL shape and serializer implementation are intentionally unchanged because their measured execution cost is small compared with queueing and framework overhead.

## 1. Evidence from the benchmark

| Concurrency | Requests | Success | E2E p50 ms | E2E p95 ms | E2E p99 ms | View boundary p50 ms | View boundary p95 ms | Server p50 ms | Server p95 ms | DB p50 ms | DB p95 ms | Pool p50 ms | Pool p95 ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 400 | 400 | 9.27 | 11.32 | 13.50 | 5.79 | 7.24 | 7.48 | 9.15 | 1.04 | 1.27 | 0.24 | 0.29 |
| 25 | 400 | 400 | 120.66 | 170.61 | 221.44 | 51.06 | 84.68 | 108.77 | 156.27 | 7.02 | 18.00 | 3.76 | 15.28 |
| 50 | 400 | 400 | 242.95 | 336.09 | 357.45 | 143.51 | 222.42 | 231.24 | 317.44 | 8.18 | 19.19 | 80.12 | 136.79 |
| 100 | 400 | 400 | 508.80 | 1200.34 | 1392.23 | 389.44 | 998.87 | 468.36 | 1135.05 | 7.54 | 16.86 | 266.76 | 841.22 |

### Read of the numbers

- At concurrency 100, full-stack E2E p95 is **1200.34 ms**, while DB p95 is only **16.86 ms**. The database query itself is therefore not responsible for the ~1.2 s tail.
- The full-stack view boundary reaches **998.87 ms p95** at concurrency 100. This boundary includes downstream work seen by Django around the view; it is not a claim that Python code inside the view alone took 998.87 ms.
- The strongest queue signal is the pool: in the newer instrumented baseline at concurrency 100, pool wait is **301.26 ms p50 / 706.53 ms p95**.
- Serializer timings are only a few milliseconds. In the instrumented baseline at C100, serializer CPU is **2.37 ms p95** and serializer wait is **8.03 ms p95**.

## 2. What the gate does

At C100, gate=4 moves pressure out of the connection pool and into an explicit async application queue.

| Configuration | E2E p50 ms | E2E p95 ms | E2E p99 ms | Admission p50 ms | Admission p95 ms | Pool p50 ms | Pool p95 ms | RPS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline-c100 | 529.81 | 918.93 | 1165.29 | 0.00 | 0.00 | 301.26 | 706.53 | 149.60 |
| gate4-c100 | 642.53 | 901.72 | 1103.33 | 401.81 | 625.24 | 12.94 | 49.78 | 176.76 |
| gate6-c100 | 99.98 | 1541.77 | 1906.49 | 0.00 | 1170.61 | 4.53 | 71.64 | 165.04 |
| gate7-c100 | 41.41 | 1677.25 | 2089.13 | 0.00 | 1227.71 | 1.64 | 84.63 | 178.89 |

**Why gate=4 wins among the tested gates:** gate=4 has the best C100 tail profile of the measured admission choices: p95 **901.72 ms** and p99 **1103.33 ms**, versus baseline p95 **918.93 ms** / p99 **1165.29 ms**, gate=6 p95 **1541.77 ms** / p99 **1906.49 ms**, and gate=7 p95 **1677.25 ms** / p99 **2089.13 ms**. It also raises successful RPS from **149.60 to 176.76**.

Gate=6 and gate=7 are rejected as the final choice because their median can look attractive while their tail becomes much worse. Production traffic normally needs predictable p95/p99, not merely a good median.

## 3. Middleware and view diagnosis

### Leave-one-out at C50

| Removed middleware | E2E p50 ms | E2E p95 ms | E2E p99 ms | Server p50 ms | Server p95 ms |
|---|---:|---:|---:|---:|---:|
| RequestCorrelationMiddleware | 235.14 | 344.30 | 372.91 | 223.50 | 327.69 |
| TrustedProxyHeadersMiddleware | 319.82 | 501.37 | 589.23 | 283.85 | 473.74 |
| CorsMiddleware | 207.30 | 368.69 | 390.66 | 196.75 | 355.06 |
| XFrameOptionsMiddleware | 222.63 | 313.72 | 336.78 | 210.09 | 297.35 |
| CommonMiddleware | 211.21 | 463.27 | 503.89 | 182.59 | 448.29 |
| CsrfViewMiddleware | 194.37 | 382.16 | 404.53 | 176.94 | 364.96 |
| SecurityMiddleware | 216.27 | 467.42 | 513.78 | 192.77 | 455.17 |
| Session/Auth/Messages group | 219.07 | 513.53 | 550.63 | 182.28 | 502.12 |

The leave-one-out runs are useful as a diagnostic signal, but they are independent load-test runs and therefore should not be treated as exact additive causal costs. The stronger finding is the full-vs-minimal stack comparison: the full Django stack becomes much more expensive in the high-concurrency tail, while the minimal async stack removes a substantial part of that overhead.

At full-stack C100, several sync Django middleware layers have exclusive p95 times in the tens of milliseconds, while at C1 they are sub-millisecond. That pattern is consistent with thread-bound queueing under concurrency rather than an intrinsically expensive middleware function.

For the API specifically, the project uses DRF stateless JWT authentication. Therefore Django session, message, CSRF, and AuthenticationMiddleware are not needed to establish the authenticated DRF API request. The optimized API settings keep request-id/perf instrumentation, trusted-proxy handling, CORS, and security headers.

## 4. PostgreSQL diagnosis

PostgreSQL is healthy for this endpoint in the benchmark environment:

| Measurement | Value |
|---|---:|
| Product-list SQL calls | 4800 |
| Product-list mean execution | 0.375 ms |
| COUNT mean execution | 0.208 ms |
| Product-list EXPLAIN execution | ~0.25 ms |
| Products | 2000 |
| Invoice items | 5000 |
| Stock balances | 2000 |

The product query uses the product-name index plus the inventory and invoice-item indexes. PostgreSQL is serving the benchmark from cache, with zero shared reads in the captured plan.

One architectural inefficiency remains: page-number pagination performs an exact `COUNT(*)` plus a separate page fetch. PostgreSQL executes both cheaply in this dataset, so this is **not** the primary bottleneck today. It is intentionally left unchanged in this pass instead of trading exact pagination semantics for an unproven gain.

## 5. Serializer diagnosis

No serializer rewrite is justified by the data.

The current `sync_to_async(..., thread_sensitive=False)` boundary measures only a few milliseconds, compared with hundreds of milliseconds of pool/admission/framework queueing. The serializer implementation is therefore retained.

## 6. Final configuration

| Component | Final choice | Reason |
|---|---|---|
| API execution | ASGI + async/ADRF | Appropriate for I/O-bound API work and avoids blocking the main event loop on DB waits |
| API middleware | Lean API-only stack | Removes unnecessary sync middleware from the hot path |
| DB pool max | 8 / worker | Bounded and compatible with the tested gate; avoids unbounded DB connection growth |
| Async DB admission | 4 / worker | Best tested p95/p99 trade-off |
| Serializer | Existing async boundary | Measured cost is tiny |
| SQL | Existing query | PostgreSQL execution is sub-millisecond in the plan diagnostic |
| Request-id | Single RequestIdAndPerf middleware | Removes duplicate request-id middleware from the API hot path |

## 7. Consistency rules

With four workers, `pool_max=8` implies up to **32 database connections** across the process group. `gate=4` implies at most **16 admitted DB-bound operations** at once across those workers. This deliberately keeps the gate below the pool size so application pressure is bounded before it becomes connection-pool contention.

The required invariants are:

`WEB_CONCURRENCY × DB_POOL_MAX_SIZE <= database connection budget`

and per worker:

`ASYNC_DB_CONCURRENCY < DB_POOL_MAX_SIZE`

This coordination matters because HTTP concurrency, DB concurrency, and DB connections are three different capacities. Increasing one without coordinating the others simply moves the queue to another layer.

## 8. Changes applied

- `core/settings/settings_prod.py`: default async DB admission changed **6 → 4**.
- Added `core/settings/settings_api.py` with the lean API middleware stack.
- `Dockerfile`: runtime default changed to `core.settings.settings_api`; static collection remains on `settings_prod`.
- SQL and serializer code were intentionally left unchanged because the measured data does not support them as root-cause fixes.

## 9. Remaining validation

The inspected artifact does not contain a completed same-commit Sync-vs-Async matrix or a live `py-spy` profile. The repository has a dedicated sync-vs-async workflow, but it was not part of this successful artifact.

Therefore this report does **not** claim that async is universally faster than sync for this endpoint. It claims that the current async stack is valid and that the measured bottleneck is queueing and framework overhead rather than PostgreSQL execution or serialization.

The next validation run should compare the new `settings_api` stack against the old full stack at C1/C10/C25/C50/C100 and capture event-loop/executor profiling at C100. The code changes in this branch are deliberately limited to the evidence-backed configuration and hot-path simplification above.
