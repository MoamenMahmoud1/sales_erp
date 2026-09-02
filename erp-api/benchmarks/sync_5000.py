#!/usr/bin/env python3
import asyncio, json, os, statistics, time
from collections import Counter
import httpx

URL = os.environ["BENCH_URL"]
TOKEN = os.environ["BENCH_TOKEN"]
REQUESTS = int(os.getenv("BENCH_REQUESTS", "5000"))
CONCURRENCY = int(os.getenv("BENCH_CONCURRENCY", "100"))
TIMEOUT = float(os.getenv("BENCH_TIMEOUT", "30"))

def pct(values, p):
    if not values: return None
    values = sorted(values)
    x = (len(values)-1)*p
    lo, hi = int(x), min(int(x)+1, len(values)-1)
    return values[lo] + (values[hi]-values[lo])*(x-lo)

async def main():
    limits = httpx.Limits(max_connections=CONCURRENCY, max_keepalive_connections=CONCURRENCY)
    timeout = httpx.Timeout(TIMEOUT)
    sem = asyncio.Semaphore(CONCURRENCY)
    rows = []
    started = time.perf_counter()
    async with httpx.AsyncClient(limits=limits, timeout=timeout, http2=False, trust_env=False) as client:
        async def one(i):
            async with sem:
                t = time.perf_counter()
                try:
                    r = await client.get(URL, headers={"Authorization": f"Bearer {TOKEN}", "Accept":"application/json"})
                    return r.status_code, (time.perf_counter()-t)*1000, None
                except Exception as e:
                    return None, (time.perf_counter()-t)*1000, type(e).__name__
        rows = await asyncio.gather(*(one(i) for i in range(REQUESTS)))
    wall = time.perf_counter()-started
    ok = [lat for status, lat, _ in rows if status is not None and 200 <= status < 300]
    failures = [r for r in rows if r[0] is None or not (200 <= r[0] < 300)]
    print(json.dumps({
        "requests": REQUESTS, "concurrency": CONCURRENCY, "wall_time_sec": wall,
        "rps": REQUESTS/wall if wall else 0, "successful": len(ok), "failed": len(failures),
        "error_rate_pct": len(failures)*100/REQUESTS,
        "mean_ms": statistics.fmean(ok) if ok else None,
        "p50_ms": pct(ok, .50), "p95_ms": pct(ok, .95), "p99_ms": pct(ok, .99),
        "status_counts": dict(Counter(str(s) for s,_,_ in rows)),
        "errors": dict(Counter(str(e) for _,_,e in rows if e)),
    }, indent=2))
    if len(ok) < REQUESTS:
        raise SystemExit(1)

asyncio.run(main())
