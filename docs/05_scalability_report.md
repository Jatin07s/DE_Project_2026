# CP4 — Scalability Report: Urban Company Home Services

- Recorded: 2026-11-23 21:50 IST
- PostgreSQL client: psql (PostgreSQL) 16.16 (Homebrew)
- Dataset: faculty-provided `large_data.zip`, 11 CSVs; 3,000,000 bookings and 800,000 customers (archive row counts).
- Reference: CP3 `benchmarks/results/optimized/summary.csv` on original dataset (150,000 bookings).
- Scale test: `benchmarks/results/large/summary.csv` using CP3 optimized workload, with 3 measured runs/query.
- Method: `EXPLAIN (ANALYZE, BUFFERS)`; WRITE statements are wrapped in BEGIN/ROLLBACK by faculty benchmark script.
- Raw execution plans are stored in both result folders; averages are independently checked against raw plans.

## 1. Actual large-dataset performance (all 30 queries)

| Query | Type | Optimized seed avg (ms) | Large avg (ms) | Time growth | Scan nodes on large data |
|---|---|---:|---:|---:|---|
| R01 | READ | 0.057 | 0.248 | 4.35× | Seq Scan on services \| Seq Scan on service_categories |
| R02 | READ | 0.903 | 16.022 | 17.74× | Index Only Scan using pk_pro_skills on pro_skills \| Bitmap Heap Scan on professionals \| Bitmap Index Scan on idx_professionals_city_status \| Index Scan using service_categories_pkey on service_categories \| Index Scan using pk_pro_availability on pro_availability \| Index Scan using idx_bookings_pro_status on bookings |
| R03 | READ | 0.070 | 0.133 | 1.90× | Seq Scan on services \| Index Scan using idx_bookings_customer_sched on bookings \| Index Scan using professionals_pkey on professionals |
| R04 | READ | 0.098 | 1.835 | 18.72× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_pro_status \| Seq Scan on services |
| R05 | READ | 0.067 | 2.633 | 39.30× | Index Scan using idx_bookings_requested_oldest on bookings |
| R06 | READ | 0.024 | 0.409 | 17.04× | Index Scan using customers_phone_key on customers |
| R07 | READ | 0.162 | 0.314 | 1.94× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_pro_status |
| R08 | READ | 0.527 | 25.373 | 48.15× | Seq Scan on professionals \| Index Scan using idx_payouts_status_week on payouts |
| R09 | READ | 1.921 | 31.661 | 16.48× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_status_schedstart \| Seq Scan on services \| Seq Scan on service_categories |
| R10 | READ | 8.529 | 116.666 | 13.68× | Index Only Scan using idx_bookings_pro_status on bookings |
| R11 | READ | 0.477 | 9.982 | 20.93× | Bitmap Heap Scan on reschedules \| Bitmap Index Scan on idx_reschedules_created \| Index Scan using bookings_pkey on bookings \| Seq Scan on services |
| R12 | READ | 1.648 | 76.094 | 46.17× | Index Scan using idx_bookings_discount_positive on bookings |
| R13 | READ | 1.267 | 40.844 | 32.24× | Seq Scan on professionals \| Index Only Scan using idx_bookings_pro_status on bookings |
| R14 | READ | 16.240 | 287.208 | 17.69× | Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_city_service \| Seq Scan on services |
| R15 | READ | 9.878 | 124.550 | 12.61× | Seq Scan on bookings \| Index Scan using idx_reviews_created on reviews |
| R16 | READ | 0.609 | 8.866 | 14.56× | Index Scan using idx_bookings_booked_at_desc on bookings |
| R17 | READ | 10.818 | 329.043 | 30.42× | Index Scan using idx_bookings_booked_at_desc on bookings \| Seq Scan on services |
| R18 | READ | 0.166 | 0.313 | 1.89× | Index Scan using idx_reviews_created on reviews |
| R19 | READ | 11.518 | 314.288 | 27.29× | Seq Scan on bookings \| Bitmap Heap Scan on professionals \| Bitmap Index Scan on idx_professionals_city_status |
| R20 | READ | 7.923 | 122.210 | 15.42× | Seq Scan on bookings |
| R21 | READ | 13.641 | 212.562 | 15.58× | Seq Scan on bookings \| Seq Scan on services \| Index Only Scan using pk_pro_skills on pro_skills |
| R22 | READ | 8.892 | 12.375 | 1.39× | Index Scan using idx_bookings_booked_at_desc on bookings |
| R23 | READ | 0.038 | 0.196 | 5.16× | Seq Scan on services \| Index Scan using bookings_pkey on bookings |
| R24 | READ | 0.749 | 18.503 | 24.70× | Index Scan using idx_bookings_cancel_fee on bookings |
| R25 | READ | 2.533 | 72.577 | 28.65× | Bitmap Heap Scan on pro_availability \| Bitmap Index Scan on idx_pro_availability_date_pro \| Bitmap Heap Scan on professionals \| Bitmap Index Scan on idx_professionals_city_status \| Bitmap Heap Scan on bookings \| Bitmap Index Scan on idx_bookings_status_schedstart |
| W01 | WRITE | 0.818 | 2.275 | 2.78× | (no scan) |
| W02 | WRITE | 10.439 | 1.077 | 0.10× | Index Only Scan using idx_bookings_requested_oldest on bookings \| Index Scan using bookings_pkey on bookings |
| W03 | WRITE | 0.240 | 0.115 | 0.48× | Index Scan using idx_bookings_pro_status on bookings |
| W04 | WRITE | 2.526 | 193.711 | 76.69× | Index Scan using idx_bookings_status_completed on bookings |
| W05 | WRITE | 2.471 | 564.658 | 228.51× | Index Scan using idx_bookings_status_schedstart on bookings |

## 2. Growth analysis

The table above compares measured execution time, not row count. The fact that bookings increased 20× does not mean every query must become 20× slower.

| Growth category | Queries (calculated from measured timings) |
|---|---|
| Near-stable (≤3×) | R03, R07, R18, R22, W01, W02, W03 |
| Intermediate (3–10×) | R01, R23 |
| Roughly proportional (~20×) | R02, R04, R06, R09, R10, R11, R14, R15, R16, R19, R20, R21, R24, R25 |
| Superlinear (>30×) | R05, R08, R12, R13, R17, W04, W05 |

### Five biggest large-data regressions

| Query | Seed avg (ms) | Large avg (ms) | Growth | Investigation priority |
|---|---:|---:|---:|---|
| W05 | 2.471 | 564.658 | 228.51× | Inspect `benchmarks/results/large/W05.txt` for scan, join, sort and buffer costs |
| W04 | 2.526 | 193.711 | 76.69× | Inspect `benchmarks/results/large/W04.txt` for scan, join, sort and buffer costs |
| R08 | 0.527 | 25.373 | 48.15× | Inspect `benchmarks/results/large/R08.txt` for scan, join, sort and buffer costs |
| R12 | 1.648 | 76.094 | 46.17× | Inspect `benchmarks/results/large/R12.txt` for scan, join, sort and buffer costs |
| R05 | 0.067 | 2.633 | 39.30× | Inspect `benchmarks/results/large/R05.txt` for scan, join, sort and buffer costs |

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

## 6.1 Faculty Performance Target Verification

| Query | Average (ms) | Target (ms) | Status |
|---|---:|---:|---|
| R01 | 0.248 | < 5 | PASS |
| R02 | 16.022 | < 5 | FAIL |
| R03 | 0.133 | < 5 | PASS |
| R04 | 1.835 | < 5 | PASS |
| R05 | 2.633 | < 5 | PASS |
| R06 | 0.409 | < 5 | PASS |
| R07 | 0.314 | < 5 | PASS |
| R08 | 25.373 | < 250 | PASS |
| R09 | 31.661 | < 5000 | PASS |
| R10 | 116.666 | < 5000 | PASS |
| R11 | 9.982 | < 250 | PASS |
| R12 | 76.094 | < 5000 | PASS |
| R13 | 40.844 | < 250 | PASS |
| R14 | 287.208 | < 5000 | PASS |
| R15 | 124.550 | < 5000 | PASS |
| R16 | 8.866 | < 250 | PASS |
| R17 | 329.043 | < 5000 | PASS |
| R18 | 0.313 | < 250 | PASS |
| R19 | 314.288 | < 5000 | PASS |
| R20 | 122.210 | < 5000 | PASS |
| R21 | 212.562 | < 5000 | PASS |
| R22 | 12.375 | < 250 | PASS |
| R23 | 0.196 | < 5 | PASS |
| R24 | 18.503 | < 5000 | PASS |
| R25 | 72.577 | < 5000 | PASS |
| W01 | 2.275 | < 5 | PASS |
| W02 | 1.077 | < 5 | PASS |
| W03 | 0.115 | < 5 | PASS |
| W04 | 193.711 | < 1000 | PASS |
| W05 | 564.658 | < 250 | FAIL |

**Result: 28/30 targets passed.**

## 6.2 Verified Scale-Only W02 Optimization

The original W02 execution plan used `bookings_pkey` to locate the oldest REQUESTED booking, filtering approximately 2.97 million unrelated records.

A partial index was added in `sql/07_scale_indexes.sql`: `ON uc.bookings (booking_id) WHERE status = 'REQUESTED'`.

- Before: **287.777 ms** average.
- After: **1.077 ms** average.
- Measured speedup: **267.20x**.
- New plan: `Index Only Scan using idx_bookings_requested_oldest`.
- Original evidence: `benchmarks/results/large/evidence/W02_before.txt`.
- Updated evidence: `benchmarks/results/large/W02.txt`.
- All WRITE benchmark executions use ROLLBACK.

R02 remains above its real-time target. Its large-data plan contains substantial skill scans, joins and sorting; further optimization and benchmark evidence are required.

## 7. Conclusion

The 30-query large-dataset measurement and growth comparison above provide a factual basis for assessing scalability. Production readiness is **not asserted** until service-level targets, critical correctness checks, and the proposed scale-only fixes are verified. Remaining risks include cross-shard joins, FK changes under partitioning, skew, stale replicas and index-maintenance cost.
