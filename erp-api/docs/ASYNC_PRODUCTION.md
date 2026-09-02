# Async production model

The API is intentionally hybrid.

## Native async path

Use `common.services.async_postgres` for read-heavy, latency-sensitive endpoints where native asyncio I/O is valuable. It uses psycopg 3 `AsyncConnectionPool` and `AsyncConnection`, and the pool is opened from the ASGI lifespan so Gunicorn `preload_app` never creates database connections in the master process.

The pool queues tasks when all connections are busy. `ASYNC_PG_MAX_WAITING=0` means an unlimited queue; deployments that need hard backpressure can set a finite value. `ASYNC_PG_POOL_TIMEOUT` bounds how long a task waits for a connection.

## Django ORM path

Keep Django ORM for normal CRUD and especially transaction-bound business operations. Django's transaction support is not async-safe yet, so invoice, payment, stock, and other atomic business operations should remain inside one synchronous transaction boundary called from an async view when needed.

## Connection budget

A worker can have two database pools:

- Django synchronous pool for transaction-bound work.
- Native async pool for migrated async reads.

Do not size these independently from the PostgreSQL connection budget. The sum of their maxima, multiplied by the number of worker processes, must fit within the database/proxy capacity with headroom for migrations, maintenance, monitoring, and administrative connections.

The API settings therefore default the native async maximum to half of the Django pool maximum. Production deployments should override both values after observing real workload and PostgreSQL utilization.

## Server model

The application is an ASGI application served by Uvicorn's Gunicorn worker. `uvicorn[standard]` is installed, so Uvicorn can use `uvloop` when supported by the platform.

For container orchestration, prefer small process counts per container and scale horizontally. For a VM/bare-metal deployment, multiple ASGI worker processes can be used to utilize multiple CPU cores. Worker count is a deployment choice, not an application constant.

## When native async is expected to win

Native async is most valuable when the request spends significant time waiting for I/O and the process has many concurrent in-flight requests. Examples include upstream HTTP calls, Redis/network I/O, SSE/WebSockets, and other long-lived connections.

A short PostgreSQL query will not become intrinsically faster because it is executed through asyncio. Native async mainly removes thread blocking while the application is waiting for the database/network and allows the event loop to make progress on other tasks.

## Benchmarking

Compare Sync and Async with the same PostgreSQL dataset, schema, query semantics, worker count, and total database connection budget. Record RPS, p50/p95/p99, CPU, memory, thread count, database connections, and request-level timing. Interpret throughput together with tail latency and downstream saturation; increasing pool size until PostgreSQL is saturated is not automatically an improvement.
