# CP1 · Schema Design — Urban Company Home Services

> **Status:** All 11 CSV files inspected and checked offline (376,932 records). **PostgreSQL 16.16 local schema creation, CSV loading and integrity checks completed successfully on 16 November 2026.** Data anomalies are listed below and are not removed.

## Source and design principles

- **Database:** PostgreSQL 15+; `uc` schema; CSV/table/column names preserved exactly.
- **Coverage:** 11 tables, 150,000 bookings; timestamp columns with `+05:30` use `TIMESTAMPTZ`, times without zone use `TIME`, monetary amounts use `NUMERIC` (never floating point).
- **Load path:** `sql/01_schema.sql`, then `sql/02_load_data.sql` from repo root using `psql` with `-v ON_ERROR_STOP=1`.
- **Index rule:** no performance indexes added now. Primary and unique constraints create their necessary indexes automatically.

## Data dictionary

The **reason** column describes the intended meaning of each typed field; constraint status should be checked against the raw exports.


### `cities`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `city_id` | `INTEGER` | PK | City identifier |
| `city_name` | `VARCHAR(100)` | NOT NULL; UNIQUE with state; CHECK nonblank | Display city name |
| `state` | `VARCHAR(100)` | NOT NULL; UNIQUE with city; CHECK nonblank | State name |


### `service_categories`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `category_id` | `INTEGER` | PK | Category identifier |
| `category_name` | `VARCHAR(120)` | NOT NULL; UNIQUE; CHECK nonblank | Service taxonomy label |


### `services`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `service_id` | `INTEGER` | PK | Service identifier |
| `category_id` | `INTEGER` | NOT NULL; FK → service_categories | Category ownership |
| `service_name` | `VARCHAR(180)` | NOT NULL; UNIQUE within category; CHECK nonblank | Menu label |
| `duration_min` | `INTEGER` | NOT NULL; CHECK > 0 | Positive duration |
| `base_price` | `NUMERIC(12,2)` | NOT NULL; CHECK ≥ 0 | Base price in INR |
| `is_active` | `BOOLEAN` | NOT NULL | Menu availability |


### `professionals`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `pro_id` | `INTEGER` | PK | Professional identifier |
| `full_name` | `VARCHAR(150)` | NOT NULL | Professional name |
| `phone` | `VARCHAR(20)` | NOT NULL; UNIQUE; CHECK nonblank | Contact lookup |
| `city_id` | `INTEGER` | NOT NULL; FK → cities | Home city |
| `gender` | `VARCHAR(10)` | NOT NULL; CHECK M/F | Values observed are M and F |
| `joined_on` | `DATE` | NOT NULL | Join date |
| `rating` | `NUMERIC(3,2)` | NULL; CHECK 0–5 | Stored aggregate review rating (cache) |
| `kyc_verified` | `BOOLEAN` | NOT NULL | KYC status |
| `status` | `VARCHAR(32)` | NOT NULL; CHECK ACTIVE/SUSPENDED/OFFBOARDED | Partner account state |


### `pro_skills`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `pro_id` | `INTEGER` | PK part; FK → professionals | Certified professional |
| `category_id` | `INTEGER` | PK part; FK → service_categories | Certified service category |
| `certified_on` | `DATE` | NOT NULL | Date of certification |


### `pro_availability`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `pro_id` | `INTEGER` | PK part; FK → professionals | Professional with availability |
| `work_date` | `DATE` | PK part | Local working day |
| `start_time` | `TIME` | NOT NULL; CHECK < end_time | Local shift start |
| `end_time` | `TIME` | NOT NULL; CHECK > start_time | Local shift end |


### `customers`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `customer_id` | `INTEGER` | PK | Customer identifier |
| `full_name` | `VARCHAR(150)` | NOT NULL | Customer display name |
| `phone` | `VARCHAR(20)` | NOT NULL; UNIQUE; CHECK nonblank | Contact lookup |
| `email` | `VARCHAR(255)` | NULL; UNIQUE; CHECK not blank when present | Optional email |
| `city_id` | `INTEGER` | NOT NULL; FK → cities | Customer city |
| `plus_valid_until` | `DATE` | NULL | Optional Plus membership end date |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Account creation instant |


### `bookings`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `booking_id` | `BIGINT` | PK | Booking identifier |
| `customer_id` | `INTEGER` | NOT NULL; FK → customers | Booking owner |
| `service_id` | `INTEGER` | NOT NULL; FK → services | Booked service |
| `pro_id` | `INTEGER` | NULL; FK → professionals | Assignee; missing for requested and some customer-cancelled jobs |
| `city_id` | `INTEGER` | NOT NULL; FK → cities | Service city |
| `pincode` | `VARCHAR(6)` | NOT NULL; 6-digit CHECK | Delivery/visit postal code |
| `booked_at` | `TIMESTAMPTZ` | NOT NULL | Booking creation instant |
| `scheduled_start` | `TIMESTAMPTZ` | NOT NULL; < scheduled_end | Current appointment start |
| `scheduled_end` | `TIMESTAMPTZ` | NOT NULL; > scheduled_start | Appointment end snapshot |
| `started_at` | `TIMESTAMPTZ` | NULL | Actual job start |
| `completed_at` | `TIMESTAMPTZ` | NULL | Actual job end |
| `status` | `VARCHAR(32)` | NOT NULL; CHECK allowed statuses and lifecycle consistency | Booking lifecycle state |
| `price` | `NUMERIC(12,2)` | NOT NULL; ≥ 0 | Agreed price |
| `discount` | `NUMERIC(12,2)` | NOT NULL; 0 ≤ discount ≤ price | Money saved |
| `cancellation_fee` | `NUMERIC(12,2)` | NOT NULL; ≥ 0; positive only for customer cancellations | Cancellation charge |
| `tip` | `NUMERIC(12,2)` | NULL; ≥ 0; only on completed bookings | Optional partner tip |
| `payment_method` | `VARCHAR(32)` | NOT NULL; CHECK UPI/CASH/CARD/WALLET | Payment category |


### `reschedules`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `reschedule_id` | `BIGINT` | PK | Reschedule event identifier |
| `booking_id` | `BIGINT` | NOT NULL; FK → bookings | Affected booking |
| `old_start` | `TIMESTAMPTZ` | NOT NULL; ≠ new_start | Original slot |
| `new_start` | `TIMESTAMPTZ` | NOT NULL; ≠ old_start | Replacement slot |
| `requested_by` | `VARCHAR(20)` | NOT NULL; CHECK CUSTOMER/PRO | Reschedule initiator |
| `reason` | `TEXT` | NULL | Reason text |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Change logged at |


### `reviews`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `booking_id` | `BIGINT` | PK; FK → bookings | One review row per booking |
| `rating_for_pro` | `SMALLINT` | NOT NULL; CHECK 1–5 | Customer rating for professional |
| `comment` | `TEXT` | NULL | Optional feedback |
| `rating_for_customer` | `SMALLINT` | NULL; CHECK 1–5 when present | Professional rating for customer |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Review timestamp |


### `payouts`

| CSV column | PostgreSQL type | Constraints / key | Reason |
|---|---|---|---|
| `payout_id` | `BIGINT` | PK | Payout identifier |
| `pro_id` | `INTEGER` | NOT NULL; FK → professionals; UNIQUE with week_start | Payee |
| `week_start` | `DATE` | NOT NULL; UNIQUE with pro_id; Monday CHECK | Payroll period |
| `jobs` | `INTEGER` | NOT NULL; > 0 | Number of paid jobs |
| `gross_earnings` | `NUMERIC(14,2)` | NOT NULL; ≥ 0 | Gross payable |
| `commission` | `NUMERIC(14,2)` | NOT NULL; 0 to gross | Platform commission |
| `net_payout` | `NUMERIC(14,2)` | NOT NULL; gross − commission | Final payout |
| `status` | `VARCHAR(24)` | NOT NULL; CHECK PAID/PENDING; paid_at consistency | Transfer state |
| `paid_at` | `TIMESTAMPTZ` | NULL | Transfer instant, absent if pending |


## Keys, deletion policy and relationships

| Parent → child | Relationship | Action | Reason |
|---|---|---|---|
| cities → professionals, customers, bookings | 1:N | RESTRICT | Prevent loss of referenced geographic history |
| service_categories → services | 1:N | RESTRICT | Preserve historic service definitions |
| service_categories → pro_skills | 1:N | RESTRICT | Prevent deleting a category still certified |
| professionals → pro_skills, pro_availability | 1:N | CASCADE | Auxiliary skill/availability rows do not stand alone |
| professionals → bookings | 1:N (nullable) | RESTRICT | Preserve accountable professional identity for historical jobs; use soft-offboarding instead of deletion |
| professionals → payouts | 1:N | RESTRICT | Financial accounting history must survive |
| customers → bookings | 1:N | RESTRICT | Keep history (privacy deletions require separate legal workflow) |
| services → bookings | 1:N | RESTRICT | A past booking must retain its service reference |
| bookings → reschedules | 1:N | CASCADE | Child history depends on booking identity |
| bookings → reviews | 1:0..1 | CASCADE | Review is specific to one booking |

**M:N:** professionals ↔ service_categories via `pro_skills` with composite PK `(pro_id, category_id)`.

**Verified in the CSVs:** one availability interval per professional and work date (no duplicate `(pro_id, work_date)` among 70,407 rows); `payout_id` and `(pro_id, week_start)` are unique; reviews have no duplicate `booking_id`.

**ER files:** `diagrams/er_diagram.png` (image) and `diagrams/er_diagram.mmd` (editable Mermaid source).

## Functional dependencies and normal forms

| Relation | Main functional dependencies (FDs) | Normalization observation |
|---|---|---|
| cities | `city_id → city_name, state`; `(city_name, state) → city_id` if unique | BCNF (all stated determinants candidate keys) |
| service_categories | `category_id → category_name`; `category_name → category_id` | BCNF |
| services | `service_id → all other attributes`; `(category_id,service_name) → service_id` | BCNF under uniqueness assumption |
| professionals | `pro_id → all other attributes`; `phone → pro_id` | Base row BCNF; `rating` is a denormalized, computed review aggregate |
| pro_skills | `(pro_id,category_id) → certified_on` | BCNF; complete composite-key dependence |
| pro_availability | `(pro_id,work_date) → start_time,end_time` | BCNF **if** one interval/day assumption holds |
| customers | `customer_id → all other attributes`; `phone → customer_id` | BCNF under unique phone assumption |
| bookings | `booking_id → all other attributes` | Intended BCNF record; `scheduled_end` can be derived from duration but stored as a historical scheduling snapshot |
| reschedules | `reschedule_id → booking_id,old_start,new_start,requested_by,reason,created_at` | BCNF |
| reviews | `booking_id → rating_for_pro,comment,rating_for_customer,created_at` | BCNF; 0 or 1 row per booking |
| payouts | `payout_id → all other attributes`; `(pro_id,week_start) → payout_id` | A snapshot with **deliberate redundancy**: `gross_earnings,commission → net_payout` formula means strict BCNF/3NF claims need qualification |

**Rationale for derived data:** `professionals.rating` speeds display but must be refreshed from reviews; `bookings.scheduled_end` retains the actual promised time even if menu duration changes; `payouts` records period-close audited totals. Such snapshots require consistency checks rather than pretending there is no redundancy.

## CHECK constraints (audited against the seed CSV values)

The DDL contains more than 12 CHECK constraints, including: nonblank city/state/category/service names; positive service duration; nonnegative base price; professional 0–5 rating; positive working interval; 6-digit pincode; appointment end after start; nonnegative price, discount, cancellation fee and tip; discount not above price; changed reschedule slot; reschedule actor list; 1–5 review ratings; Monday payroll week; nonnegative jobs and payout amounts; commission within gross; and gross minus commission equal to net. The specified row-level predicates were checked on CSV values with zero violations; execute the DDL and load on PostgreSQL to validate database-specific behavior.

### NULL decisions confirmed in the seed CSVs

`bookings.pro_id` is nullable for REQUESTED jobs; `started_at` / `completed_at` may be missing for non-completed jobs; `tip` is optional; `customers.plus_valid_until` is optional; `professionals.rating` can be missing before sufficient reviews; `reviews.rating_for_customer` is optional; `payouts.paid_at` is absent until paid. Additionally, `customers.email` is optional. Observed missing values: `bookings.pro_id` 6,142, `started_at` and `completed_at` 22,308 each, `tip` 124,473; `customers.email` 11,920; `customers.plus_valid_until` 32,869; `professionals.rating` 72; `reviews.rating_for_customer` 22,869; `payouts.paid_at` 1,080. Null `pro_id` is valid for all 84 REQUESTED bookings and 6,058 customer cancellations. There are no empty cells in required primary/foreign-key columns. 

## Validation checklist and integrity queries

**CSV audit results are reported below and must be cross-checked against the output of the PostgreSQL integrity script after importing the data.** Nonzero results are real business-data quality exceptions; they must not be silently deleted.

```bash
unzip seed_data.zip -d .  # creates seed_data/*.csv at repository root
createdb urban_company  # if not already created
psql -X -v ON_ERROR_STOP=1 -d urban_company -f sql/01_schema.sql
psql -X -v ON_ERROR_STOP=1 -d urban_company -f sql/02_load_data.sql
psql -X -v ON_ERROR_STOP=1 -d urban_company -f sql/03_integrity_checks.sql
```

> The extra `sql/03_integrity_checks.sql` is a convenient CP1 helper; it is **not** a replacement for the required deliverables.

| Test | CSV-level result | Meaning / next step |
|---|---:|---|
| Row counts across 11 files | **376,932** (all 11 counts match) | Check imported PostgreSQL row counts match these |
| Duplicate primary/candidate keys | **0** | Composite `pro_skills`, `pro_availability`, `reviews` and weekly payout keys valid |
| Missing foreign-key references | **0** | Null `bookings.pro_id` counted as permitted, not orphan |
| Overlapping ASSIGNED/IN_PROGRESS booking pairs for same professional | **6** | Dispatch data issue; do not delete records or assert perfect scheduling |
| COMPLETED jobs without matching `pro_skills` entry | **1,000** | Quality/compliance exception (query R21) |
| Assigned/completed jobs outside a recorded June–July shift | **1,349** | Check time-window coverage; not an FK error |
| June–July pro-linked jobs with no shift record | **1,177** | Availability coverage gap (all statuses) |
| Payouts not starting Monday or violating gross − commission = net | **0** | Arithmetic/date checks valid |
| Payouts with jobs/gross mismatch against completed bookings for the given week | **0** | Weekly aggregates reconciled offline using Asia/Kolkata completion dates |

**Database execution evidence (16 November 2026):**

- Environment: PostgreSQL 16.16 (Homebrew), macOS.
- Database: `urban_company`; schema: `uc`.
- `sql/01_schema.sql` executed successfully.
- `sql/02_load_data.sql` completed with `COMMIT` and `ANALYZE`.
- All 11 table row counts matched the faculty dataset.
- Total loaded records: **376,932**.
- All checks below were executed using `sql/03_integrity_checks.sql`.

| Integrity check | Actual PostgreSQL result |
|---|---:|
| Tables with matching expected row counts | 11/11 |
| Overlapping booking pairs | 6 |
| Completed bookings without matching skills | 1,000 |
| Jobs outside recorded shifts | 1,349 |
| Jobs without a shift record | 1,177 |
| Invalid payout calculations | 0 |

The nonzero counts represent observed data-quality issues, not data-loading failures. The locally executed shift query returned 1,349, which supersedes the earlier offline estimate of 1,310.


## Observed data-quality findings and design decisions

1. **Unskilled completions:** 1,000 completed bookings reference a professional with no certification for that service's category. Example booking `101`. The existing source data is accepted and query R21 is expected to surface these. A cross-table certification rule cannot be enforced using a simple `CHECK` on bookings.
2. **Double bookings:** 6 overlapping pairs among still-assigned jobs. Scheduling conflicts require transactional checks or exclusion constraints later; CP1 instructions permit only PK/FK/UNIQUE/NOT NULL/CHECK, so no exclusion constraint is added.
3. **Availability:** of June–July pro-linked bookings, 1,177 have no shift row; among assigned/completed jobs with a shift, 1,349 fall partly outside it. Do not fabricate working hours to make these anomalies disappear.
4. **Payouts:** `gross_earnings`, `commission` and `net_payout` are accounting snapshot fields. The supplied arithmetic and week key checks pass. Do not impose `commission = 20% of gross`: tips and service-value rules can differ.
5. **Normal-form caveat:** `payouts.net_payout` is derived from amounts in the same row; it is retained intentionally as a financial snapshot and protected by a `CHECK`, rather than claiming unqualified BCNF for every business dependency.
6. **No tuning indexes:** only indexes generated by PK and UNIQUE constraints exist in CP1.
