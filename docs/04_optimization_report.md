# CP3 · Optimization Report — Urban Company Home Services

## 1. Executive Summary

This report documents the performance optimization (Phase 4 / Checkpoint 3) of the Urban Company Home Services database workload across all 30 benchmark queries (25 read queries `R01`–`R25` and 5 write queries `W01`–`W05`).

Optimization was achieved through targeted B-tree, composite, and partial indexing (`sql/05_indexes.sql`) alongside strategic query rewrites (`sql/06_optimized_queries.sql`), without altering any business logic or dataset state.

### Key Results
- **Total Workload Execution Time:** reduced from **5,548.470 ms** to **115.249 ms**.
- **Overall Speedup:** **48.1× faster** (a **97.9% reduction** in total query latency).
- **Extreme Bottlenecks Eliminated:** Query `R25` dropped from 2,097.08 ms to 2.53 ms (**827.9× faster**), and Query `R19` dropped from 3,220.03 ms to 11.52 ms (**279.6× faster**).
- **Subtle SQL Bug Discovered & Fixed:** Query `R13` previously returned **0 rows** due to SQL three-valued logic with `NULL` values in a `NOT IN` subquery; rewriting to `NOT EXISTS` resolved problem statement P5 and restored the true result set of **377 professionals**.

---

## 2. Environment & Methodology

- **Database:** PostgreSQL 18.6 (Postgres.app)
- **Database Name:** `urban_company`
- **Schema:** `uc` (11 relational tables, 376,932 records; 150,000 bookings)
- **Measurement Method:** `./benchmarks/run_benchmark.sh urban_company <baseline|optimized> 3`
- **Measurement Standard:** 3 consecutive runs per query using `EXPLAIN (ANALYZE, BUFFERS)`; reported times are the arithmetic mean of the three execution times.
- **Transactional Safety:** Write queries (`W01`–`W05`) executed inside `BEGIN; ... ROLLBACK;` blocks to preserve database integrity across runs.

---

## 3. Comprehensive Optimization Table (All 30 Queries)

| Query | Baseline (ms) | Problem Identified in Plan | Optimization Applied | Optimized (ms) | Improvement (%) | Speedup | Same Result? |
|---|---:|---|---|---:|---:|---:|:---:|
| **R01** | 0.078 | Full scan on tiny lookup tables (60 services, 10 categories) | Kept as-is; planner correctly prefers sequential scan on single-page tables | 0.057 | 26.9% | 1.4× | ✅ |
| **R02** | 8.938 | Seq scan on `bookings` for `NOT EXISTS` anti-join; Seq scan on `professionals` | Composite index `(pro_id, status)` on bookings; `(city_id, status)` on professionals | 0.903 | 89.9% | 9.9× | ✅ |
| **R03** | 5.972 | Seq scan on 150k `bookings` rows filtered by customer | Composite index `bookings(customer_id, scheduled_start)` | 0.070 | 98.8% | 85.3× | ✅ |
| **R04** | 4.441 | Non-sargable `DATE(scheduled_start)` prevented index scan; Seq scan on 150k bookings | Rewrote to sargable range `[2026-07-02, 2026-07-03)`; used `bookings(pro_id, status)` | 0.098 | 97.8% | 45.3× | ✅ |
| **R05** | 7.382 | Seq scan on 150k `bookings` looking for `status = 'REQUESTED'` | Composite index `bookings(status, scheduled_start)` | 0.067 | 99.1% | 110.2× | ✅ |
| **R06** | 0.023 | Already optimal; uses UNIQUE index on `customers(phone)` | Kept as-is | 0.024 | -4.3% | 1.0× | ✅ |
| **R07** | 5.281 | Seq scan on 150k `bookings` filtering on professional + status | Filtered via composite index `bookings(pro_id, status)` | 0.162 | 96.9% | 32.6× | ✅ |
| **R08** | 1.432 | Seq scan on 27,015 `payouts` rows | Composite index `payouts(status, week_start)` | 0.527 | 63.2% | 2.7× | ✅ |
| **R09** | 5.995 | Seq scan on 150k `bookings` for COMPLETED jobs in June 2026 | Composite index `bookings(status, scheduled_start)` | 1.921 | 68.0% | 3.1× | ✅ |
| **R10** | 16.829 | Seq scan on 150k `bookings` with in-memory hash aggregate | Index-only scan using `bookings(pro_id, status)` skipping NULL pro_ids | 8.529 | 49.3% | 2.0× | ✅ |
| **R11** | 0.643 | Seq scan on 5,391 `reschedules` rows for June 2026 date range | B-tree index `reschedules(created_at)` | 0.477 | 25.8% | 1.3× | ✅ |
| **R12** | 7.223 | Seq scan on 150k `bookings` filtering `discount > 0` and 2026 | Partial index `bookings(booked_at) WHERE discount > 0` | 1.648 | 77.2% | 4.4× | ✅ |
| **R13** | 7.618 | `NOT IN` subquery returned NULL, yielding 0 rows (P5); Seq scan on 150k bookings | Rewrote to `NOT EXISTS` (fixing NULL bug); index-only anti-join on `bookings(pro_id, status)` | 1.267 | 83.4% | 6.0× | ⚠️ Fixed (0 → 377 rows) |
| **R14** | 19.251 | Seq scan on 150k `bookings` for Bengaluru bookings | Composite index `bookings(city_id, service_id)` | 16.240 | 15.6% | 1.2× | ✅ |
| **R15** | 11.651 | Seq scan on 76,539 `reviews` rows | B-tree index `reviews(created_at)` | 9.878 | 15.2% | 1.2× | ✅ |
| **R16** | 4.791 | Seq scan on 150k `bookings` for Mumbai June 2026 bookings | Composite index `bookings(city_id, booked_at)` | 0.609 | 87.3% | 7.9× | ✅ |
| **R17** | 13.904 | Seq scan on 150k `bookings` for 2026 COMPLETED bookings | Index range scan on `bookings(booked_at DESC)` and status filter | 10.818 | 22.2% | 1.3× | ✅ |
| **R18** | 14.209 | Full sequential scan on 76,539 reviews evaluating `ILIKE '%late%'` | Reverse index scan on `reviews(created_at)` with early limit cutoff + GIN trgm | 0.166 | 98.8% | 85.6× | ✅ |
| **R19** | 3220.028 | Two correlated subqueries executed 357 times (714 full scans of 150k bookings = 107M rows visited) | Rewrote correlated subqueries to a single `LEFT JOIN` with `FILTER (...)`; index on `professionals(city_id, status)` | 11.518 | 99.6% | 279.6× | ✅ |
| **R20** | 8.453 | Full scan of June 2026 bookings for daily GMV window computation | Filtered scan on `bookings(status, scheduled_start)` | 7.923 | 6.3% | 1.1× | ✅ |
| **R21** | 13.676 | Scans 127,692 COMPLETED bookings to find 1,000 uncertified jobs | Index `pro_skills(category_id, pro_id)` assists NOT EXISTS anti-join | 13.641 | 0.3% | 1.0× | ✅ |
| **R22** | 29.956 | Full table sort of 150,000 rows spilled to disk (`external merge Disk: 7464kB`) for `OFFSET 100000` | Backward index scan on `bookings(booked_at DESC)` avoids sorting entirely | 8.892 | 70.3% | 3.4× | ✅ |
| **R23** | 0.050 | Single row lookup by PK on `bookings` | Kept as-is; uses `bookings_pkey` | 0.038 | 24.0% | 1.3× | ✅ |
| **R24** | 9.426 | Full sequential scan on 150k `bookings` searching for rare cancellation fees | Partial index `bookings(scheduled_start) WHERE cancellation_fee > 0` | 0.749 | 92.1% | 12.6× | ✅ |
| **R25** | 2097.081 | Correlated subquery on bookings executed 357 times (357 × 150k = 53.5M rows visited) | Rewrote correlated subquery to pre-aggregated `LEFT JOIN`; indexes on availability, pros, and bookings | 2.533 | 99.9% | 827.9× | ✅ |
| **W01** | 0.834 | Single row INSERT into `bookings` | Unchanged; tested write overhead with 11 table indexes | 0.818 | 1.9% | 1.0× | ✅ |
| **W02** | 11.058 | Subquery `min(booking_id)` on `bookings` | Assisted by index on `bookings(status, scheduled_start)` | 10.439 | 5.6% | 1.1× | ✅ |
| **W03** | 6.585 | Seq scan on 150k `bookings` to locate professional 425's assigned job | Index scan on `bookings(pro_id, status)` directly locates target row | 0.240 | 96.4% | 27.4× | ✅ |
| **W04** | 8.710 | Seq scan on 150k `bookings` for weekly completed job aggregation | Index scan on `bookings(status, completed_at)` directly filters June 29–July 6 rows | 2.526 | 71.0% | 3.4× | ✅ |
| **W05** | 6.952 | Seq scan on 150k `bookings` to find unstarted assigned jobs | Index scan on `bookings(status, scheduled_start)` | 2.471 | 64.5% | 2.8× | ✅ |
| **Total** | **5,548.470** | | | **115.249** | **97.9%** | **48.1×** | |

---

## 4. The Wrong-Result Query: The SQL `NULL` Pitfall in `R13`

### The Problem in Problem Statement P5
In Phase 1, the Partner Success team reported:
> *"The partner-rewards list of pros with no customer cancellations always comes back empty."*

### Why the Original Query Failed
The original query was written as:
```sql
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
WHERE p.status = 'ACTIVE'
  AND p.pro_id NOT IN (
      SELECT b.pro_id 
      FROM bookings b 
      WHERE b.status = 'CANCELLED_BY_CUSTOMER'
  );
```
In SQL's three-valued logic (`TRUE`, `FALSE`, `UNKNOWN`), `x NOT IN (val1, val2, ...)` expands to:
$$(x \ne val_1) \land (x \ne val_2) \land \dots \land (x \ne NULL)$$

In the seed dataset, out of 6,142 bookings without an assigned professional (`pro_id IS NULL`), **6,058 are bookings with `status = 'CANCELLED_BY_CUSTOMER'`** (where the customer cancelled before dispatch assigned a professional).

When the inner subquery returns even a single `NULL`:
$$(x \ne NULL) \implies \text{UNKNOWN}$$
Consequently, the entire `AND` conjunction evaluates to `UNKNOWN` for every professional. Since the `WHERE` clause accepts only rows evaluating to `TRUE`, **the query returned exactly 0 rows**.

### The Fix
In `sql/06_optimized_queries.sql`, we replaced `NOT IN` with `NOT EXISTS`:
```sql
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
WHERE p.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.pro_id = p.pro_id
        AND b.status = 'CANCELLED_BY_CUSTOMER'
  );
```
`NOT EXISTS` operates on two-valued existential quantification: it evaluates whether matching rows exist for that specific `p.pro_id`. Subquery rows where `b.pro_id IS NULL` never equate to `p.pro_id`, correctly returning **377 active professionals** who genuinely have zero customer cancellations. Furthermore, `NOT EXISTS` allows PostgreSQL to plan an efficient Anti-Join using `idx_bookings_pro_status`, speeding up execution from **7.62 ms** to **1.27 ms** (6.0× faster).

---

## 5. Deep-Dive: Execution Plans for the 5 Biggest Improvements

### 1. `R25` — Capacity Utilisation (2,097.08 ms → 2.53 ms, 827.9× Speedup)
- **Bottleneck:** The original query executed a correlated subquery calculating booked minutes for every single Bengaluru professional:
  ```text
  GroupAggregate (actual time=9.469..2097.180 loops=1)
    SubPlan 1
      -> Aggregate (loops=357)
        -> Seq Scan on bookings b (actual time=5.202..5.245 loops=357)
             Filter: ((scheduled_start >= '2026-06-22') AND (scheduled_start < '2026-06-29') AND (pro_id = a.pro_id) AND (status = 'COMPLETED'))
             Rows Removed by Filter: 149999
  ```
  PostgreSQL performed 357 full sequential scans of `bookings` (357 × 150,000 = 53,550,000 row inspections), taking over 2 seconds.
- **Optimization:** 
  1. Rewrote the correlated subquery into a pre-aggregated subquery joined via `LEFT JOIN`.
  2. Applied `idx_pro_availability_date_pro` on availability dates.
  3. Applied `idx_bookings_status_schedstart` on `(status, scheduled_start)`.
- **Optimized Plan:**
  ```text
  Limit (actual time=2.605..2.608 loops=1)
    -> Sort (Sort Method: top-N heapsort)
      -> Hash Left Join (actual time=2.477..2.557)
        -> HashAggregate (pa.pro_id)
          -> Bitmap Heap Scan on pro_availability pa using idx_pro_availability_date_pro
        -> Subquery Scan on bk
          -> HashAggregate (b.pro_id)
            -> Bitmap Heap Scan on bookings b using idx_bookings_status_schedstart
  ```
  Total execution time fell to **2.53 ms** (828× faster; 99.9% time reduction).

---

### 2. `R19` — City Completed Jobs & Last Date (3,220.03 ms → 11.52 ms, 279.6× Speedup)
- **Bottleneck:** The baseline query contained *two* correlated subqueries in the `SELECT` list (`june_jobs` count and `last_job_at` max). For all 357 active Bengaluru professionals, both subqueries executed a sequential scan of `bookings`:
  $$357 \times 2 = 714 \text{ full table scans} \implies 714 \times 150,000 = 107,100,000 \text{ rows examined}$$
  Total execution time was **3,220.03 ms**.
- **Optimization:** 
  1. Refactored both correlated subqueries into a single `LEFT JOIN` on `bookings b ON b.pro_id = p.pro_id`.
  2. Used PostgreSQL conditional aggregation `count(*) FILTER (WHERE b.status = 'COMPLETED' AND b.scheduled_start >= '2026-06-01' AND b.scheduled_start < '2026-07-01')`.
  3. Filtered professionals using `idx_professionals_city_status`.
- **Optimized Plan:**
  ```text
  Sort (actual time=11.444..11.451 rows=357 loops=1)
    -> HashAggregate (Group Key: p.pro_id)
      -> Hash Right Join (Hash Cond: b.pro_id = p.pro_id)
        -> Seq Scan on bookings b (single pass over table)
        -> Hash
          -> Bitmap Heap Scan on professionals p using idx_professionals_city_status
  ```
  Instead of 714 sequential scans, `bookings` is scanned exactly once in a Hash Join. Execution dropped to **11.52 ms** (280× faster).

---

### 3. `R05` — Dispatch Requested Jobs (7.38 ms → 0.07 ms, 110.2× Speedup)
- **Bottleneck:** Full table scan across all 150,000 bookings looking for the 46 rows with `status = 'REQUESTED'` and `scheduled_start < '2026-07-02 12:00:00'`:
  ```text
  Seq Scan on bookings (actual time=7.234..7.292 rows=46 loops=1)
    Filter: ((scheduled_start < '2026-07-02 12:00:00+05:30') AND (status = 'REQUESTED'))
    Rows Removed by Filter: 149954
  ```
- **Optimization:** Created composite index `idx_bookings_status_schedstart` on `bookings(status, scheduled_start)`.
- **Optimized Plan:**
  ```text
  Index Scan using idx_bookings_status_schedstart on bookings (actual time=0.019..0.045 rows=46 loops=1)
    Index Cond: ((status = 'REQUESTED') AND (scheduled_start < '2026-07-02 12:00:00+05:30'))
    Buffers: shared hit=46
  ```
  Execution dropped from 7.38 ms to **0.067 ms** (110× faster), reading 46 buffer blocks instead of 2,544.

---

### 4. `R18` — Quality Lateness Reviews (14.21 ms → 0.17 ms, 85.6× Speedup)
- **Bottleneck:** The baseline query scanned all 76,539 reviews evaluating the pattern match `comment ILIKE '%late%'` and sorted all matches:
  ```text
  Limit (actual time=14.395..14.398 rows=50 loops=1)
    -> Sort (actual time=14.394..14.396 rows=50 loops=1)
      -> Seq Scan on reviews r (actual time=0.007..13.837 rows=7772 loops=1)
           Filter: (comment ~~* '%late%')
           Rows Removed by Filter: 68767
  ```
- **Optimization:** Created index `reviews(created_at)` and trigram GIN index `idx_reviews_comment_trgm`. The optimizer chose a backward index scan on `created_at` with filter condition, stopping as soon as 50 matching reviews were retrieved:
- **Optimized Plan:**
  ```text
  Limit (actual time=0.007..0.158 rows=50 loops=1)
    -> Index Scan Backward using idx_reviews_created on reviews r
         Filter: (comment ~~* '%late%')
         Rows Removed by Filter: 529
  ```
  Instead of scanning 76,539 rows, it only scanned 579 index tuples, stopping early at 50 results in **0.166 ms** (85.6× faster).

---

### 5. `R03` — Customer Upcoming Bookings (5.97 ms → 0.07 ms, 85.3× Speedup)
- **Bottleneck:** Sequential scan on `bookings` (150,000 rows) filtering on `customer_id = 226` and `scheduled_start >= '2026-07-01'`:
  ```text
  Seq Scan on bookings b (actual time=6.298..6.299 rows=1 loops=1)
    Filter: ((scheduled_start >= '2026-07-01') AND (customer_id = 226))
    Rows Removed by Filter: 149999
  ```
- **Optimization:** Created composite index `idx_bookings_customer_sched` on `bookings(customer_id, scheduled_start)`.
- **Optimized Plan:**
  ```text
  Index Scan using idx_bookings_customer_sched on bookings b (actual time=0.008..0.008 rows=1 loops=1)
    Index Cond: ((customer_id = 226) AND (scheduled_start >= '2026-07-01'))
    Buffers: shared hit=4
  ```
  Execution dropped from 5.97 ms to **0.070 ms** (85.3× faster), reading only 4 shared buffer hits.

---

## 6. Write Overhead Analysis

Adding indexes introduces maintenance overhead during data modification (`INSERT`, `UPDATE`, `DELETE`). The table below compares the 5 write operations before and after index creation:

| Write Query | Description | Baseline Avg (ms) | Optimized Avg (ms) | Speedup / Overhead | Evaluation |
|---|---|---:|---:|---:|---|
| **W01** | INSERT single booking (AC service) | 0.834 | 0.818 | 1.0× (±0.02 ms) | **Negligible Overhead:** Even with 11 indexes on `bookings`, insert latency remains well under 1 ms. |
| **W02** | UPDATE single oldest requested booking | 11.058 | 10.439 | 1.1× faster | **Faster:** The subquery finding `min(booking_id)` uses index-assisted targeting. |
| **W03** | UPDATE partner job to completed + tip | 6.585 | 0.240 | **27.4× faster** | **Massive Win:** Baseline scanned 150k rows; `idx_bookings_pro_status` pinpoints the single target row instantly. |
| **W04** | INSERT payouts from completed jobs | 8.710 | 2.526 | **3.4× faster** | **Faster:** Filter on `status = 'COMPLETED'` and date range uses `idx_bookings_status_completed`. |
| **W05** | UPDATE unstarted jobs to NO_SHOW | 6.952 | 2.471 | **2.8× faster** | **Faster:** `idx_bookings_status_schedstart` filters the small candidate pool instead of scanning 150k rows. |

### Conclusion on Write Overhead
Counter-intuitively, **4 out of 5 write queries became substantially faster**, and the remaining one (`W01`) exhibited virtually no measurable latency degradation. This occurred because in OLTP write operations that include `WHERE` filters (`UPDATE` and `INSERT ... SELECT`), the time saved by eliminating full table scans is an order of magnitude larger than the small CPU and I/O cost of updating B-tree leaf pages.

---

## 7. Index Storage Breakdown

The sizes of all tables and indexes were measured using `pg_relation_size()`:

| Table | Table Data Size | Index Name | Index Size | Type / Key Structure | Purpose / Queries Served |
|---|---:|---|---:|---|---|
| **bookings** | 20 MB | `bookings_pkey` | 3,312 kB | B-tree PK `(booking_id)` | Constraint index (CP1) |
| | | `idx_bookings_pro_status` | 1,288 kB | B-tree `(pro_id, status)` | R02, R07, R10, R13, R21, W03 |
| | | `idx_bookings_customer_sched` | 4,640 kB | B-tree `(customer_id, scheduled_start)` | R03 ("My bookings") |
| | | `idx_bookings_status_schedstart` | 2,248 kB | B-tree `(status, scheduled_start)` | R05, R09, R20, R25, W05 |
| | | `idx_bookings_city_booked` | 4,640 kB | B-tree `(city_id, booked_at)` | R16 (Mumbai top pincodes) |
| | | `idx_bookings_city_service` | 1,056 kB | B-tree `(city_id, service_id)` | R14 (Demand heat-map) |
| | | `idx_bookings_booked_at_desc` | 3,320 kB | B-tree `(booked_at DESC)` | R17, R22 (Deep pagination) |
| | | `idx_bookings_status_completed` | 4,872 kB | B-tree `(status, completed_at)` | W04 (Weekly payout batch) |
| | | `idx_bookings_status_sched` | 2,248 kB | B-tree `(status, scheduled_start)` | Dispatch and slot conflict checks |
| | | `idx_bookings_service` | 1,056 kB | B-tree `(service_id)` | Foreign key joins |
| | | `idx_bookings_discount_positive` | 464 kB | **Partial B-tree** `(booked_at) WHERE discount > 0` | R12 (Plus member savings) |
| | | `idx_bookings_cancel_fee` | 96 kB | **Partial B-tree** `(scheduled_start) WHERE cancellation_fee > 0` | R24 (Cancellation fees) |
| **reviews** | 5,120 kB | `reviews_pkey` | 1,696 kB | B-tree PK `(booking_id)` | Constraint index (CP1) |
| | | `idx_reviews_created` | 1,680 kB | B-tree `(created_at)` | R15, R18 |
| | | `idx_reviews_comment_trgm` | 2,344 kB | GIN `(comment gin_trgm_ops)` | R18 (`comment ILIKE '%late%'`) |
| **pro_availability**| 3,592 kB | `pk_pro_availability` | 1,512 kB | B-tree PK `(pro_id, work_date)` | Constraint index (CP1) |
| | | `idx_pro_availability_date_pro`| 1,560 kB | B-tree `(work_date, pro_id)` | R25 (Availability date range) |
| **payouts** | 2,416 kB | `payouts_pkey` | 616 kB | B-tree PK `(payout_id)` | Constraint index (CP1) |
| | | `uq_payout_pro_week` | 792 kB | B-tree UNIQUE `(pro_id, week_start)` | Constraint index (CP1) |
| | | `idx_payouts_status_week` | 224 kB | B-tree `(status, week_start)` | R08 (Pending payouts) |
| **professionals** | 216 kB | `professionals_pkey` | 72 kB | B-tree PK `(pro_id)` | Constraint index (CP1) |
| | | `professionals_phone_key` | 96 kB | B-tree UNIQUE `(phone)` | Constraint index (CP1) |
| | | `idx_professionals_city_status` | 40 kB | B-tree `(city_id, status)` | R02, R19, R25 (City filtering) |
| **pro_skills** | 224 kB | `pk_pro_skills` | 128 kB | B-tree PK `(pro_id, category_id)` | Constraint index (CP1) |
| | | `idx_pro_skills_cat_pro` | 128 kB | B-tree `(category_id, pro_id)` | R02, R21 (Reverse skill lookup) |
| **reschedules** | 504 kB | `reschedules_pkey` | 136 kB | B-tree PK `(reschedule_id)` | Constraint index (CP1) |
| | | `idx_reschedules_created` | 136 kB | B-tree `(created_at)` | R11 (June reschedules) |
| **customers** | 3,712 kB | Constraints (PK, phone, email) | 4,200 kB | B-tree (PK, UNIQUE) | Constraint indexes (CP1) |
| **cities / services** | 24 kB | Constraints (PK, UNIQUE) | 96 kB | B-tree (PK, UNIQUE) | Small lookup tables |
| **Total Database** | **35.8 MB** | **All Indexes** | **39.0 MB** | *(New Tuning Indexes: 31.3 MB)* | Highly compact memory footprint |

---

## 8. Queries That Could Not Be Sped Up Significantly (and Why)

An honest query analysis recognizes that certain queries cannot or should not be forced onto index scans:

1. **`R01` (Service Menu: 0.078 ms → 0.057 ms):**
   - *Reason:* The `services` table has 60 rows and `service_categories` has 10 rows. Each fits entirely on a single 8 KB disk page. The query planner's cost model knows that an index scan would require reading the index page followed by the heap page (2 page I/Os), whereas a sequential scan reads the single page directly (1 page I/O). The query is already executing in 57 microseconds.
2. **`R06` (Customer by Phone: 0.023 ms → 0.024 ms):**
   - *Reason:* The table already possessed a UNIQUE B-tree index on `phone` from CP1 (`customers_phone_key`). The query was already performing a direct index lookup in 23 microseconds; no further optimization is possible.
3. **`R21` (Unskilled Job Compliance Audit: 13.68 ms → 13.64 ms):**
   - *Reason:* To verify compliance, the engine must inspect all 127,692 COMPLETED bookings in the dataset (85.1% of the entire table). The optimizer determines that streaming all table blocks sequentially with parallel sequential scanning is faster than traversing random index pages for 85% of the table rows. The anti-join against `pro_skills` is accelerated via `idx_pro_skills_cat_pro`, but the scan of completed bookings remains a bulk sequential operation.
4. **`R14` (Demand Planning Heat-Map: 19.25 ms → 16.24 ms) & `R20` (Daily GMV: 8.45 ms → 7.92 ms):**
   - *Reason:* Both queries perform large aggregations (`GROUP BY` across 23,919 and 12,000+ rows respectively). Index scans reduce data retrieval time, but the remaining wall-clock time is dominated by CPU-bound mathematical calculations (e.g., extracting ISO day of week, hours, running window sums, and grouping hashes). In Phase 5, these heavy reporting queries can be offloaded to refreshable materialized views.

---

## 9. Verification of Unchanged Query Results

To satisfy the grading requirement that optimized queries produce identical results, every rewritten query was verified using row counts, ordering checks, and SQL set difference (`EXCEPT`):

```sql
-- Example validation query
(SELECT ... FROM original_query)
EXCEPT
(SELECT ... FROM optimized_query);
```

- **R01–R12, R14–R18, R20–R24:** Result sets match **100% identically** in row count, column values, and ordering.
- **R19 & R25:** The multiset of rows produced is identical for every professional; minor order variations only occur among records tied on the same metric (`june_jobs` or `booked_min`) because the problem specification lacks a secondary tie-breaking column in `ORDER BY`.
- **R13:** Result count intentionally changed from **0 rows to 377 rows**, resolving the three-valued logic SQL `NULL` trap and fulfilling the Phase 1 problem requirement P5.
- **W01–W05:** Target rows modified, inserted, and updated match the exact business requirements without data drift.
