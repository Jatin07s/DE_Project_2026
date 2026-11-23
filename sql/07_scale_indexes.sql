-- CP4: Scale-only optimization for W02.
-- Find the oldest REQUESTED booking without scanning
-- millions of unrelated booking records.

CREATE INDEX IF NOT EXISTS idx_bookings_requested_oldest
ON uc.bookings (booking_id)
WHERE status = 'REQUESTED';

ANALYZE uc.bookings;

-- CP4: R02 slot-picker optimization.
-- Fetch Bengaluru active professionals in rating order.
CREATE INDEX IF NOT EXISTS idx_professionals_city_status_rating
ON uc.professionals
(city_id, status, rating DESC NULLS LAST, pro_id)
INCLUDE (full_name);

ANALYZE uc.professionals;
