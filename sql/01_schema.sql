-- CP1: Urban Company Home Services, PostgreSQL 15+
-- Columns, key cardinality and constraint domains audited against all 11 seed CSVs.
-- PostgreSQL import must still be executed and recorded on your local machine.
-- Do NOT add tuning indexes in CP1. PK and UNIQUE create implicit indexes.

CREATE SCHEMA IF NOT EXISTS uc;
SET search_path TO uc, public;

CREATE TABLE cities (
    city_id       INTEGER PRIMARY KEY,
    city_name     VARCHAR(100) NOT NULL,
    state         VARCHAR(100) NOT NULL,
    CONSTRAINT uq_cities_name_state UNIQUE (city_name, state),
    CONSTRAINT ck_cities_name_nonblank CHECK (BTRIM(city_name) <> ''),
    CONSTRAINT ck_cities_state_nonblank CHECK (BTRIM(state) <> '')
);

CREATE TABLE service_categories (
    category_id   INTEGER PRIMARY KEY,
    category_name VARCHAR(120) NOT NULL UNIQUE,
    CONSTRAINT ck_categories_name_nonblank CHECK (BTRIM(category_name) <> '')
);

CREATE TABLE services (
    service_id    INTEGER PRIMARY KEY,
    category_id   INTEGER NOT NULL,
    service_name  VARCHAR(180) NOT NULL,
    duration_min  INTEGER NOT NULL,
    base_price    NUMERIC(12, 2) NOT NULL,
    is_active     BOOLEAN NOT NULL,
    CONSTRAINT fk_services_category FOREIGN KEY (category_id)
        REFERENCES service_categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_services_category_name UNIQUE (category_id, service_name),
    CONSTRAINT ck_services_duration CHECK (duration_min > 0),
    CONSTRAINT ck_services_base_price CHECK (base_price >= 0),
    CONSTRAINT ck_services_name_nonblank CHECK (BTRIM(service_name) <> '')
);

CREATE TABLE professionals (
    pro_id        INTEGER PRIMARY KEY,
    full_name     VARCHAR(150) NOT NULL,
    phone         VARCHAR(20) NOT NULL UNIQUE,
    city_id       INTEGER NOT NULL,
    gender        VARCHAR(10) NOT NULL,
    joined_on     DATE NOT NULL,
    rating        NUMERIC(3, 2),
    kyc_verified  BOOLEAN NOT NULL,
    status        VARCHAR(32) NOT NULL,
    CONSTRAINT fk_professionals_city FOREIGN KEY (city_id)
        REFERENCES cities(city_id) ON DELETE RESTRICT,
    CONSTRAINT ck_professionals_rating CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CONSTRAINT ck_professionals_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT ck_professionals_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'OFFBOARDED')),
    CONSTRAINT ck_professionals_phone_nonblank CHECK (BTRIM(phone) <> ''),
    CONSTRAINT ck_professionals_status_nonblank CHECK (BTRIM(status) <> '')
);

CREATE TABLE customers (
    customer_id      INTEGER PRIMARY KEY,
    full_name        VARCHAR(150) NOT NULL,
    phone            VARCHAR(20) NOT NULL UNIQUE,
    email            VARCHAR(255) UNIQUE,
    city_id          INTEGER NOT NULL,
    plus_valid_until DATE,
    created_at       TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_customers_city FOREIGN KEY (city_id)
        REFERENCES cities(city_id) ON DELETE RESTRICT,
    CONSTRAINT ck_customers_phone_nonblank CHECK (BTRIM(phone) <> ''),
    CONSTRAINT ck_customers_email_nonblank CHECK (email IS NULL OR BTRIM(email) <> '')
);

CREATE TABLE pro_skills (
    pro_id        INTEGER NOT NULL,
    category_id   INTEGER NOT NULL,
    certified_on  DATE NOT NULL,
    CONSTRAINT pk_pro_skills PRIMARY KEY (pro_id, category_id),
    CONSTRAINT fk_pro_skills_pro FOREIGN KEY (pro_id)
        REFERENCES professionals(pro_id) ON DELETE CASCADE,
    CONSTRAINT fk_pro_skills_category FOREIGN KEY (category_id)
        REFERENCES service_categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE pro_availability (
    pro_id       INTEGER NOT NULL,
    work_date    DATE NOT NULL,
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    -- Verified: unique (pro_id, work_date) across all 70,407 CSV rows.
    CONSTRAINT pk_pro_availability PRIMARY KEY (pro_id, work_date),
    CONSTRAINT fk_pro_availability_pro FOREIGN KEY (pro_id)
        REFERENCES professionals(pro_id) ON DELETE CASCADE,
    CONSTRAINT ck_availability_start_before_end CHECK (start_time < end_time)
);

CREATE TABLE bookings (
    booking_id        BIGINT PRIMARY KEY,
    customer_id       INTEGER NOT NULL,
    service_id        INTEGER NOT NULL,
    pro_id            INTEGER,
    city_id           INTEGER NOT NULL,
    pincode           VARCHAR(6) NOT NULL,
    booked_at         TIMESTAMPTZ NOT NULL,
    scheduled_start   TIMESTAMPTZ NOT NULL,
    scheduled_end     TIMESTAMPTZ NOT NULL,
    started_at        TIMESTAMPTZ,
    completed_at      TIMESTAMPTZ,
    status            VARCHAR(32) NOT NULL,
    price             NUMERIC(12,2) NOT NULL,
    discount          NUMERIC(12,2) NOT NULL DEFAULT 0,
    cancellation_fee  NUMERIC(12,2) NOT NULL DEFAULT 0,
    tip               NUMERIC(12,2),
    payment_method    VARCHAR(32) NOT NULL,
    CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_bookings_service FOREIGN KEY (service_id)
        REFERENCES services(service_id) ON DELETE RESTRICT,
    CONSTRAINT fk_bookings_pro FOREIGN KEY (pro_id)
        REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    CONSTRAINT fk_bookings_city FOREIGN KEY (city_id)
        REFERENCES cities(city_id) ON DELETE RESTRICT,
    CONSTRAINT ck_bookings_pincode CHECK (pincode ~ '^[0-9]{6}$'),
    CONSTRAINT ck_bookings_slot_order CHECK (scheduled_end > scheduled_start),
    CONSTRAINT ck_bookings_booked_before_start CHECK (booked_at <= scheduled_start),
    CONSTRAINT ck_bookings_status CHECK (status IN
        ('REQUESTED','ASSIGNED','IN_PROGRESS','COMPLETED',
         'CANCELLED_BY_CUSTOMER','CANCELLED_BY_PRO','NO_SHOW')),
    CONSTRAINT ck_bookings_requested_unassigned CHECK (status <> 'REQUESTED' OR pro_id IS NULL),
    CONSTRAINT ck_bookings_assigned_has_pro CHECK
        (status NOT IN ('ASSIGNED','IN_PROGRESS','COMPLETED','NO_SHOW','CANCELLED_BY_PRO') OR pro_id IS NOT NULL),
    CONSTRAINT ck_bookings_completion_consistency CHECK
        ((status = 'COMPLETED' AND started_at IS NOT NULL AND completed_at IS NOT NULL)
         OR (status <> 'COMPLETED' AND completed_at IS NULL)),
    CONSTRAINT ck_bookings_completion_order CHECK
        (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at)),
    CONSTRAINT ck_bookings_price CHECK (price >= 0),
    CONSTRAINT ck_bookings_discount_nonnegative CHECK (discount >= 0),
    CONSTRAINT ck_bookings_discount_cap CHECK (discount <= price),
    CONSTRAINT ck_bookings_cancel_fee CHECK (cancellation_fee >= 0),
    CONSTRAINT ck_bookings_cancel_fee_status CHECK
        (cancellation_fee = 0 OR status = 'CANCELLED_BY_CUSTOMER'),
    CONSTRAINT ck_bookings_tip CHECK (tip IS NULL OR tip >= 0),
    CONSTRAINT ck_bookings_tip_completed CHECK (tip IS NULL OR status = 'COMPLETED'),
    CONSTRAINT ck_bookings_status_nonblank CHECK (BTRIM(status) <> ''),
    CONSTRAINT ck_bookings_payment_nonblank CHECK (BTRIM(payment_method) <> ''),
    CONSTRAINT ck_bookings_payment_method CHECK (payment_method IN ('UPI','CASH','CARD','WALLET'))
);

CREATE TABLE reschedules (
    reschedule_id BIGINT PRIMARY KEY,
    booking_id    BIGINT NOT NULL,
    old_start     TIMESTAMPTZ NOT NULL,
    new_start     TIMESTAMPTZ NOT NULL,
    requested_by  VARCHAR(20) NOT NULL,
    reason        TEXT,
    created_at    TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_reschedules_booking FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id) ON DELETE CASCADE,
    CONSTRAINT ck_reschedules_changed CHECK (old_start <> new_start),
    CONSTRAINT ck_reschedules_actor CHECK (requested_by IN ('CUSTOMER','PRO'))
);

CREATE TABLE reviews (
    booking_id          BIGINT PRIMARY KEY,
    rating_for_pro      SMALLINT NOT NULL,
    comment             TEXT,
    rating_for_customer SMALLINT,
    created_at          TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_reviews_booking FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id) ON DELETE CASCADE,
    CONSTRAINT ck_review_pro_rating CHECK (rating_for_pro BETWEEN 1 AND 5),
    CONSTRAINT ck_review_customer_rating CHECK
        (rating_for_customer IS NULL OR rating_for_customer BETWEEN 1 AND 5)
);

CREATE TABLE payouts (
    payout_id       BIGINT PRIMARY KEY,
    pro_id          INTEGER NOT NULL,
    week_start      DATE NOT NULL,
    jobs            INTEGER NOT NULL,
    gross_earnings  NUMERIC(14,2) NOT NULL,
    commission      NUMERIC(14,2) NOT NULL,
    net_payout      NUMERIC(14,2) NOT NULL,
    status          VARCHAR(24) NOT NULL,
    paid_at         TIMESTAMPTZ,
    CONSTRAINT fk_payouts_pro FOREIGN KEY (pro_id)
        REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    CONSTRAINT uq_payout_pro_week UNIQUE (pro_id, week_start),
    CONSTRAINT ck_payout_week_monday CHECK (EXTRACT(ISODOW FROM week_start) = 1),
    CONSTRAINT ck_payout_jobs CHECK (jobs > 0),
    CONSTRAINT ck_payout_gross CHECK (gross_earnings >= 0),
    CONSTRAINT ck_payout_commission CHECK (commission >= 0),
    CONSTRAINT ck_payout_net CHECK (net_payout >= 0),
    CONSTRAINT ck_payout_commission_cap CHECK (commission <= gross_earnings),
    CONSTRAINT ck_payout_arithmetic CHECK (net_payout = gross_earnings - commission),
    CONSTRAINT ck_payout_status_nonblank CHECK (BTRIM(status) <> ''),
    CONSTRAINT ck_payout_status CHECK (status IN ('PAID','PENDING')),
    CONSTRAINT ck_payout_paid_at CHECK
        ((status = 'PAID' AND paid_at IS NOT NULL) OR
         (status = 'PENDING' AND paid_at IS NULL))
);
