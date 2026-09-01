# Middleware latency diagnostic

The baseline compares the production middleware stack against the truly minimal async stack.
Leave-one-out cases remove exactly one production middleware to estimate causal contribution.

## End-to-end cases

| case | concurrency | p50 | p95 | p99 | server p50 | db p50 | pool p50 | failed | complete |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|

## Leave-one-out at concurrency 50

| removed middleware | p50 | p95 | p99 | delta vs full-c50 | server p50 |
|---|---:|---:|---:|---:|---:|

## Per-middleware timing from full-c25

| middleware | inclusive p50 | inclusive p95 | exclusive p50 | exclusive p95 | coverage |
|---|---:|---:|---:|---:|---:|
