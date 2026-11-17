# CP2 — Baseline Timings

## Environment

- Project: Urban Company Home Services
- Database: `urban_company`
- Schema: `uc` (11 tables)
- PostgreSQL: 18.6 (Postgres.app)
- Dataset: 150,000 bookings
- Benchmark date: 17 November 2026
- Runs per query: 3
- Measurement: `EXPLAIN (ANALYZE, BUFFERS)`
- WRITE queries executed with `ROLLBACK`

## Results

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01 | READ | 0.096 | 0.071 | 0.068 | 0.078 |
| R02 | READ | 10.608 | 8.523 | 7.684 | 8.938 |
| R03 | READ | 6.347 | 5.960 | 5.609 | 5.972 |
| R04 | READ | 4.614 | 4.354 | 4.356 | 4.441 |
| R05 | READ | 7.317 | 7.512 | 7.318 | 7.382 |
| R06 | READ | 0.023 | 0.024 | 0.022 | 0.023 |
| R07 | READ | 5.342 | 5.251 | 5.250 | 5.281 |
| R08 | READ | 1.493 | 1.415 | 1.388 | 1.432 |
| R09 | READ | 6.026 | 5.964 | 5.996 | 5.995 |
| R10 | READ | 16.945 | 16.743 | 16.798 | 16.829 |
| R11 | READ | 0.685 | 0.630 | 0.615 | 0.643 |
| R12 | READ | 7.367 | 7.037 | 7.266 | 7.223 |
| R13 | READ | 7.610 | 7.705 | 7.540 | 7.618 |
| R14 | READ | 19.574 | 18.953 | 19.225 | 19.251 |
| R15 | READ | 11.740 | 11.677 | 11.536 | 11.651 |
| R16 | READ | 5.062 | 4.648 | 4.663 | 4.791 |
| R17 | READ | 14.216 | 13.795 | 13.701 | 13.904 |
| R18 | READ | 14.410 | 14.000 | 14.218 | 14.209 |
| R19 | READ | 3204.968 | 3238.635 | 3216.480 | 3220.028 |
| R20 | READ | 9.105 | 8.369 | 7.886 | 8.453 |
| R21 | READ | 13.796 | 13.717 | 13.514 | 13.676 |
| R22 | READ | 30.416 | 29.711 | 29.741 | 29.956 |
| R23 | READ | 0.056 | 0.046 | 0.048 | 0.050 |
| R24 | READ | 10.290 | 9.096 | 8.893 | 9.426 |
| R25 | READ | 2097.330 | 2108.255 | 2085.657 | 2097.081 |
| W01 | WRITE | 0.851 | 0.791 | 0.859 | 0.834 |
| W02 | WRITE | 12.275 | 10.313 | 10.587 | 11.058 |
| W03 | WRITE | 6.712 | 6.593 | 6.449 | 6.585 |
| W04 | WRITE | 9.071 | 8.545 | 8.513 | 8.710 |
| W05 | WRITE | 7.022 | 6.929 | 6.906 | 6.952 |

## Execution Plans

The raw execution plans for all 30 queries are stored in
`benchmarks/results/baseline/` as R01.txt–R25.txt
and W01.txt–W05.txt.

The `summary.csv` file includes average, median,
minimum, maximum, and scan-node information.

These results represent the unoptimized baseline
before the next performance optimization checkpoint.

