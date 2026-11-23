-- CP4: Scale-only optimization for W02.
-- Find the oldest REQUESTED booking without scanning
-- millions of unrelated booking records.

CREATE INDEX IF NOT EXISTS idx_bookings_requested_oldest
ON uc.bookings (booking_id)
WHERE status = 'REQUESTED';

ANALYZE uc.bookings;
