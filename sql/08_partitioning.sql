-- CP4 / Urban Company: Safe PostgreSQL RANGE partitioning demonstration.
-- Run in the loaded LARGE database: psql -X -v ON_ERROR_STOP=1 -d urban_company_large -f sql/08_partitioning.sql
-- This is a transaction-scoped prototype: it does NOT modify or partition uc.bookings.
-- Demonstrates partition pruning on booked_at and the partition-key PRIMARY KEY rule.
-- On a production migration, referencing FKs to uc.bookings(booking_id) require redesign:
-- PostgreSQL partitioned UNIQUE/PRIMARY KEY constraints must include booked_at.

\set ON_ERROR_STOP on
BEGIN;

-- Copy table column types, but deliberately do not copy old single-column PK,
-- foreign keys, defaults, indexes or check constraints into this small prototype.
CREATE TABLE uc.bookings_cp4_partition_demo
  (LIKE uc.bookings EXCLUDING DEFAULTS EXCLUDING GENERATED EXCLUDING IDENTITY
                    EXCLUDING CONSTRAINTS EXCLUDING INDEXES)
PARTITION BY RANGE (booked_at);

CREATE TABLE uc.bookings_cp4_2025 PARTITION OF uc.bookings_cp4_partition_demo
  FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');
CREATE TABLE uc.bookings_cp4_2026 PARTITION OF uc.bookings_cp4_partition_demo
  FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');
CREATE TABLE uc.bookings_cp4_other PARTITION OF uc.bookings_cp4_partition_demo DEFAULT;

-- A PK on a partitioned table must include the partition key booked_at.
-- This composite key is demonstrative; it does NOT solve the production FK design.
ALTER TABLE uc.bookings_cp4_partition_demo
  ADD PRIMARY KEY (booking_id, booked_at);

-- Sampling is solely for demonstrable pruning, NOT the actual large benchmark.
-- The large benchmark always runs against the full, unmodified uc.bookings table.
INSERT INTO uc.bookings_cp4_partition_demo
  SELECT * FROM uc.bookings TABLESAMPLE SYSTEM (1)
  WHERE booked_at IS NOT NULL;
ANALYZE uc.bookings_cp4_partition_demo;

-- Check the nonempty prototype and its per-partition row counts.
SELECT tableoid::regclass AS partition_name, COUNT(*) AS sampled_rows
FROM uc.bookings_cp4_partition_demo
GROUP BY tableoid ORDER BY 1;

-- Inspect plan: only the 2025 partition should be present in the scan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM uc.bookings_cp4_partition_demo
WHERE booked_at >= TIMESTAMPTZ '2025-06-01 00:00:00+00'
  AND booked_at < TIMESTAMPTZ '2025-07-01 00:00:00+00';

ROLLBACK;
-- Prototype partition tables vanish; uc.bookings remains untouched.
