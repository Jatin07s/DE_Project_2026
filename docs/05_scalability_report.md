# CP4 — Scalability Report: Urban Company Home Services

- Recorded: 2026-11-23 22:05 IST
- PostgreSQL client: psql (PostgreSQL) 16.16 (Homebrew)
- Dataset: faculty-provided `large_data.zip`, 11 CSVs; 3,000,000 bookings and 800,000 customers (archive row counts).
- Reference: CP3 `benchmarks/results/optimized/summary.csv` on original dataset (150,000 bookings).
- Scale test: `benchmarks/results/large/summary.csv` using CP3 optimized workload, with 3 measured runs/query.
- Method: `EXPLAIN (ANALYZE, BUFFERS)`; WRITE statements are wrapped in BEGIN/ROLLBACK by faculty benchmark script.
- Raw execution plans are stored in both result folders; averages are independently checked against raw plans.

## 1. Actual large-dataset performance (all 30 queries)

| Query | Type | Optimized seed avg (ms) | Large avg (ms) | Time growth | Scan nodes on large data |
|---|---|---:|---:|---:|---|
| R01 | READ | 0.057 | 0.176 | 3.09× | Seq Scan on services \| Seq Scan on service_categories |
| R02 | READ | 0.903 | 0.732 | 0.81× | Index Only Scan using idx_professionals_city_status_rating on professionals \| Index Only Scan using pk_pro_skills on pro_skills \| Index Scan using service_categories_pkey on service_categories \| Index Scan using pk_pro_availability on pro_availability \| Index Scan using idx_bookings_pro_status on bookings |
| R03 | READ | 0.070 | 0.157 | 2.24× | Seq Scan on services \| Index Scan using idx_bookings_customer_sched on bookings \| Index Scan using professionals_pkey on professionals |
| R04 | READ | 0.098 | 0.610 | 6.22× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_pro_status \| Seq Scan on services |
| R05 | READ | 0.067 | 2.093 | 31.24× | Index Scan using idx_bookings_requested_oldest on bookings |
| R06 | READ | 0.024 | 0.273 | 11.38× | Index Scan using customers_phone_key on customers |
| R07 | READ | 0.162 | 0.350 | 2.16× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_pro_status |
| R08 | READ | 0.527 | 23.490 | 44.57× | Seq Scan on professionals \| Index Scan using idx_payouts_status_week on payouts |
| R09 | READ | 1.921 | 20.014 | 10.42× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_status_schedstart \| Seq Scan on services \| Seq Scan on service_categories |
| R10 | READ | 8.529 | 82.690 | 9.70× | Index Only Scan using idx_bookings_pro_status on bookings |
| R11 | READ | 0.477 | 8.159 | 17.10× | Bitmap Heap Scan on reschedules \| Bitmap Index Scan on idx_reschedules_created \| Index Scan using bookings_pkey on bookings \| Seq Scan on services |
| R12 | READ | 1.648 | 53.440 | 32.43× | Index Scan using idx_bookings_discount_positive on bookings |
| R13 | READ | 1.267 | 21.767 | 17.18× | Index Only Scan using idx_professionals_city_status_rating on professionals \| Index Only Scan using idx_bookings_pro_status on bookings |
| R14 | READ | 16.240 | 243.586 | 15.00× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_city_service \| Seq Scan on services |
| R15 | READ | 9.878 | 134.572 | 13.62× | Seq Scan on bookings \| Index Scan using idx_reviews_created on reviews |
| R16 | READ | 0.609 | 9.891 | 16.24× | Index Scan using idx_bookings_booked_at_desc on bookings |
| R17 | READ | 10.818 | 328.685 | 30.38× | Index Scan using idx_bookings_booked_at_desc on bookings \| Seq Scan on services |
| R18 | READ | 0.166 | 0.276 | 1.66× | Index Scan using idx_reviews_created on reviews |
| R19 | READ | 11.518 | 305.015 | 26.48× | Seq Scan on bookings \| Index Only Scan using idx_professionals_city_status_rating on professionals |
| R20 | READ | 7.923 | 115.551 | 14.58× | Seq Scan on bookings |
| R21 | READ | 13.641 | 194.710 | 14.27× | Seq Scan on bookings \| Seq Scan on services \| Index Only Scan using pk_pro_skills on pro_skills |
| R22 | READ | 8.892 | 14.710 | 1.65× | Index Scan using idx_bookings_booked_at_desc on bookings |
| R23 | READ | 0.038 | 0.053 | 1.39× | Seq Scan on services \| Index Scan using bookings_pkey on bookings |
| R24 | READ | 0.749 | 15.932 | 21.27× | Index Scan using idx_bookings_cancel_fee on bookings |
| R25 | READ | 2.533 | 64.207 | 25.35× | Bitmap Heap Scan on pro_availability \| Bitmap Index Scan on idx_pro_availability_date_pro \| Index Only Scan using idx_professionals_city_status_rating on professionals \| Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_status_schedstart |
| W01 | WRITE | 0.818 | 1.473 | 1.80× | (no scan) |
| W02 | WRITE | 10.439 | 1.224 | 0.12× | Index Only Scan using idx_bookings_requested_oldest on bookings \| Index Scan using bookings_pkey on bookings |
| W03 | WRITE | 0.240 | 0.144 | 0.60× | Index Scan using idx_bookings_pro_status on bookings |
| W04 | WRITE | 2.526 | 181.579 | 71.88× | Index Scan using idx_bookings_status_completed on bookings |
| W05 | WRITE | 2.471 | 431.761 | 174.73× | Index Scan using idx_bookings_status_schedstart on bookings |

## 2. Growth analysis

The table above compares measured execution time, not row count. The fact that bookings increased 20× does not mean every query must become 20× slower.

| Growth category | Queries (calculated from measured timings) |
|---|---|
| Near-stable (≤3×) | R02, R03, R07, R18, R22, R23, W01, W02, W03 |
| Intermediate (3–10×) | R01, R04, R10 |
| Roughly proportional (~20×) | R06, R09, R11, R13, R14, R15, R16, R19, R20, R21, R24, R25 |
| Superlinear (>30×) | R05, R08, R12, R17, W04, W05 |

### Five biggest large-data regressions

| Query | Seed avg (ms) | Large avg (ms) | Growth | Investigation priority |
|---|---:|---:|---:|---|
| W05 | 2.471 | 431.761 | 174.73× | Inspect `benchmarks/results/large/W05.txt` for scan, join, sort and buffer costs |
| W04 | 2.526 | 181.579 | 71.88× | Inspect `benchmarks/results/large/W04.txt` for scan, join, sort and buffer costs |
| R08 | 0.527 | 23.490 | 44.57× | Inspect `benchmarks/results/large/R08.txt` for scan, join, sort and buffer costs |
| R12 | 1.648 | 53.440 | 32.43× | Inspect `benchmarks/results/large/R12.txt` for scan, join, sort and buffer costs |
| R05 | 0.067 | 2.093 | 31.24× | Inspect `benchmarks/results/large/R05.txt` for scan, join, sort and buffer costs |

## 3. Measured database storage

| Database | DB size | Table heap size (uc schema) | Index size (uc schema) | Total table storage (uc schema) |
|---|---:|---:|---:|---:|
| urban_company | 55.7 MiB | 35.1 MiB | 12.3 MiB | 47.7 MiB |
| urban_company_large | 1.4 GiB | 697.0 MiB | 740.1 MiB | 1.4 GiB |

## 4. Partitioning proof and production constraints

- `sql/08_partitioning.sql` demonstrates `RANGE (booked_at)` for `uc.bookings` in a transaction-scoped prototype.
- The demo uses an approximately 1% **sample only** to illustrate partition pruning. All 30 large benchmark queries run on the full original `uc.bookings`, not the sample.
- The captured execution plan and partition names are in `benchmarks/results/large/partition_pruning.txt`.
- A PostgreSQL partitioned PRIMARY KEY or UNIQUE constraint must include the partition column `booked_at`. The original single-column `booking_id` key and referencing foreign keys cannot simply be copied over.
- Production migration requires FK redesign (e.g., composite references or a separate globally unique booking-identity table), partition-aware query predicates, and comparison tests before cutover.
- A query filtering `scheduled_start` without `booked_at` may not prune `booked_at` partitions; test actual query patterns before committing to this choice.

## 5. 100× scaling architecture — proposal (not benchmarked)

- **Partitioning:** Start with monthly or quarterly RANGE partitions on `booked_at`, only if the major access paths include compatible date ranges. Archive old partitions and keep indexes local.
- **Sharding:** A `customer_id` hash key helps customer-history lookups, but city-level dashboards, professional schedules and payouts may cross shards; a city-oriented key has the opposite trade-off and risks uneven load. Keep booking, payments and reviews co-located by a stable routing key where possible; use a cross-shard analytics pipeline.
- **Read replicas:** Route stale-tolerant read-heavy reporting and historical aggregations to replicas. Keep availability confirmation, live booking state transitions, payment/update operations and read-after-write critical flows on primary.
- **Caching:** Cache relatively stable service catalogs and category lists with explicit invalidation. Do not serve payment or immediately changing booking state from stale caches.
- **Maintenance:** Monitor autovacuum bloat, dead tuples, index growth, replication lag and slow queries; run ANALYZE after bulk loads. Consider partition retention and refreshable aggregate tables for multi-year analytics.

## 6. Scale-only issues and follow-up tests

The five regressions in section 2 are **measured candidates** for investigation, not proven root causes. For each candidate, compare relevant `EXPLAIN` nodes with optimized-seed raw plans and document whether the slowdown came from full scans, poor estimates, sort spills, join choice, or increased result cardinality.

**Required manual validation before declaring targets met:**

- [x] Check faculty-defined latency targets in your project `README.md`, classify each query as PASS/FAIL using measured large avg.
- [x] For a scale-only issue, record relevant before/after plan lines and verify any fix with fresh real benchmark output.
- [ ] Confirm the optimized SQL results have the same semantics on large data; fix any CP3-dependent query issues, especially NULL-sensitive logic.
- [x] Review the `booked_at` partitioning demo plan to verify pruning, and explain why this prototype is not a production migration.

## 6.1 Faculty Latency Target Verification

| Query | Average (ms) | Target (ms) | Result |
|---|---:|---:|---|
| R01 | 0.176 | < 5 | PASS |
| R02 | 0.732 | < 5 | PASS |
| R03 | 0.157 | < 5 | PASS |
| R04 | 0.610 | < 5 | PASS |
| R05 | 2.093 | < 5 | PASS |
| R06 | 0.273 | < 5 | PASS |
| R07 | 0.350 | < 5 | PASS |
| R08 | 23.490 | < 250 | PASS |
| R09 | 20.014 | < 5000 | PASS |
| R10 | 82.690 | < 5000 | PASS |
| R11 | 8.159 | < 250 | PASS |
| R12 | 53.440 | < 5000 | PASS |
| R13 | 21.767 | < 250 | PASS |
| R14 | 243.586 | < 5000 | PASS |
| R15 | 134.572 | < 5000 | PASS |
| R16 | 9.891 | < 250 | PASS |
| R17 | 328.685 | < 5000 | PASS |
| R18 | 0.276 | < 250 | PASS |
| R19 | 305.015 | < 5000 | PASS |
| R20 | 115.551 | < 5000 | PASS |
| R21 | 194.710 | < 5000 | PASS |
| R22 | 14.710 | < 250 | PASS |
| R23 | 0.053 | < 5 | PASS |
| R24 | 15.932 | < 5000 | PASS |
| R25 | 64.207 | < 5000 | PASS |
| W01 | 1.473 | < 5 | PASS |
| W02 | 1.224 | < 5 | PASS |
| W03 | 0.144 | < 5 | PASS |
| W04 | 181.579 | < 1000 | PASS |
| W05 | 431.761 | < 250 | FAIL |

**Result: 29/30 PASS.**

## 6.2 Verified Scale-Only Optimizations

### R02 — Slot picker

- Added an index on city, status and rating,
  including professional name for index-only access.
- Rewrote joins using EXISTS predicates.
- Before: **16.022 ms**.
- After: **0.732 ms**.
- Speedup: **21.89x**.
- Verified original and candidate returned 10 rows
  each, with zero EXCEPT ALL differences on
  the large dataset.
- Before plan: `evidence/R02_before.txt`.
- After plan: `R02.txt`.

### W02 — Oldest requested booking

- Added partial index on booking_id for
  rows whose status is REQUESTED.
- Before: **287.777 ms**.
- After: **1.224 ms**.
- Speedup: **235.18x**.
- The new execution plan uses the partial index.
- Evidence: `evidence/W02_before.txt` and `W02.txt`.

### W05 — Remaining performance limitation

- Three runs: 1138.389, 98.002, 58.893 ms.
- Average: **431.761 ms**.
- Faculty target: under 250 ms.
- Status: **FAIL**.
- Significant run-to-run variation suggests
  cache or I/O sensitivity, but the precise
  cause is not yet established.
- Further optimization and fresh benchmark
  evidence are required before claiming PASS.

All WRITE benchmark executions were wrapped
in transactions and rolled back.

Full large-data equivalence for the remaining
queries has not yet been independently verified.

## 7. Conclusion

The 30-query large-dataset measurement and growth comparison above provide a factual basis for assessing scalability. Production readiness is **not asserted** until service-level targets, critical correctness checks, and the proposed scale-only fixes are verified. Remaining risks include cross-shard joins, FK changes under partitioning, skew, stale replicas and index-maintenance cost.
