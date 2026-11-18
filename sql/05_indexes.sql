SET search_path TO uc;

-- R02, R07, R10, R13, R21, W03
CREATE INDEX idx_bookings_pro_status ON bookings (pro_id, status);

-- R03
CREATE INDEX idx_bookings_customer_sched ON bookings (customer_id, scheduled_start);

-- R05, W05
CREATE INDEX idx_bookings_status_sched ON bookings (status, scheduled_start);

-- R16
CREATE INDEX idx_bookings_city_booked ON bookings (city_id, booked_at);

-- R14
CREATE INDEX idx_bookings_city_service ON bookings (city_id, service_id);

-- R22
CREATE INDEX idx_bookings_booked_at_desc ON bookings (booked_at DESC);

-- R07, W04
CREATE INDEX idx_bookings_status_completed ON bookings (status, completed_at);

-- R09, R17, R20, R25
CREATE INDEX idx_bookings_status_schedstart ON bookings (status, scheduled_start);

-- R09, R11, R14, R17, R21
CREATE INDEX idx_bookings_service ON bookings (service_id);

-- R24
CREATE INDEX idx_bookings_cancel_fee ON bookings (scheduled_start) WHERE cancellation_fee > 0;

-- R12
CREATE INDEX idx_bookings_discount_positive ON bookings (booked_at) WHERE discount > 0;

-- R02, R19, R25
CREATE INDEX idx_professionals_city_status ON professionals (city_id, status);

-- R02, R21
CREATE INDEX idx_pro_skills_cat_pro ON pro_skills (category_id, pro_id);

-- R25
CREATE INDEX idx_pro_availability_date_pro ON pro_availability (work_date, pro_id);

-- R08
CREATE INDEX idx_payouts_status_week ON payouts (status, week_start);

-- R11
CREATE INDEX idx_reschedules_created ON reschedules (created_at);

-- R15, R18
CREATE INDEX idx_reviews_created ON reviews (created_at);

-- R18
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_reviews_comment_trgm ON reviews USING gin (comment gin_trgm_ops);

ANALYZE;
