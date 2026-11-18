-- CP3: Performance indexes for Urban Company Home Services
-- These indexes target the 30-query workload (R01–R25, W01–W05).
-- Run after sql/01_schema.sql and sql/02_load_data.sql.
-- Indexes created by PRIMARY KEY and UNIQUE constraints already exist and are NOT repeated.

SET search_path TO uc;

-- ============================================================
-- bookings: the largest table (150 000 rows) and the main
-- bottleneck in baseline execution plans.
-- ============================================================

-- B-tree on (pro_id, status): covers R02 NOT EXISTS, R07, R10, R13,
-- R19, R21, R25 correlated subqueries, W02, W03.
CREATE INDEX idx_bookings_pro_status
    ON bookings (pro_id, status);

-- B-tree on (customer_id, scheduled_start): covers R03.
CREATE INDEX idx_bookings_customer_sched
    ON bookings (customer_id, scheduled_start);

-- B-tree on (status, scheduled_start): covers R05 dispatch queue,
-- W05 no-show update.
CREATE INDEX idx_bookings_status_sched
    ON bookings (status, scheduled_start);

-- B-tree on (city_id, booked_at): covers R16 (Mumbai pincodes).
CREATE INDEX idx_bookings_city_booked
    ON bookings (city_id, booked_at);

-- B-tree on (city_id, service_id): covers R14 demand planning.
CREATE INDEX idx_bookings_city_service
    ON bookings (city_id, service_id);

-- B-tree on booked_at DESC: covers R22 support console pagination
-- (sorts entire table by booked_at DESC with OFFSET/LIMIT).
CREATE INDEX idx_bookings_booked_at_desc
    ON bookings (booked_at DESC);

-- B-tree on (status, completed_at): covers R07, W04 finance payout insert,
-- R20 daily GMV (status = 'COMPLETED' + date range on completed/scheduled).
CREATE INDEX idx_bookings_status_completed
    ON bookings (status, completed_at);

-- B-tree on (status, scheduled_start) for completed bookings: R09, R17, R20.
CREATE INDEX idx_bookings_status_schedstart
    ON bookings (status, scheduled_start);

-- B-tree on (service_id): covers FK join in R09, R11, R14, R17, R21.
CREATE INDEX idx_bookings_service
    ON bookings (service_id);

-- Partial index: cancellation_fee > 0 for R24.
CREATE INDEX idx_bookings_cancel_fee
    ON bookings (scheduled_start)
    WHERE cancellation_fee > 0;

-- Partial index: discount > 0 for R12.
CREATE INDEX idx_bookings_discount_positive
    ON bookings (booked_at)
    WHERE discount > 0;

-- ============================================================
-- professionals
-- ============================================================

-- B-tree on (city_id, status): covers R02, R19 (Bengaluru + ACTIVE filter).
CREATE INDEX idx_professionals_city_status
    ON professionals (city_id, status);

-- ============================================================
-- pro_skills
-- ============================================================

-- B-tree on (category_id, pro_id): covers R02 join on category_name
-- and R21 NOT EXISTS anti-join (category_id, pro_id).
CREATE INDEX idx_pro_skills_cat_pro
    ON pro_skills (category_id, pro_id);

-- ============================================================
-- pro_availability
-- ============================================================

-- B-tree on (work_date, pro_id): covers R25 date-range filter.
CREATE INDEX idx_pro_availability_date_pro
    ON pro_availability (work_date, pro_id);

-- ============================================================
-- payouts
-- ============================================================

-- B-tree on (status, week_start): covers R08.
CREATE INDEX idx_payouts_status_week
    ON payouts (status, week_start);

-- ============================================================
-- reschedules
-- ============================================================

-- B-tree on (created_at): covers R11 date-range filter.
CREATE INDEX idx_reschedules_created
    ON reschedules (created_at);

-- ============================================================
-- reviews
-- ============================================================

-- B-tree on (created_at): covers R15 date-range filter, R18 ORDER BY.
CREATE INDEX idx_reviews_created
    ON reviews (created_at);

-- pg_trgm GIN index for ILIKE '%late%' in R18.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_reviews_comment_trgm
    ON reviews USING gin (comment gin_trgm_ops);

-- ============================================================
-- Done.  Run ANALYZE to update planner statistics.
-- ============================================================
ANALYZE;
