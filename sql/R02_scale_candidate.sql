SET search_path TO uc;

EXPLAIN (ANALYZE, BUFFERS)
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
WHERE p.city_id = 1
  AND p.status = 'ACTIVE'

  AND EXISTS (
    SELECT 1
    FROM pro_skills ps
    JOIN service_categories c
      ON c.category_id = ps.category_id
    WHERE ps.pro_id = p.pro_id
      AND c.category_name = 'Salon for Women'
  )

  AND EXISTS (
    SELECT 1
    FROM pro_availability a
    WHERE a.pro_id = p.pro_id
      AND a.work_date = DATE '2026-07-03'
      AND a.start_time <= TIME '11:00'
      AND a.end_time >= TIME '12:30'
  )

  AND NOT EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.pro_id = p.pro_id
      AND b.status IN ('ASSIGNED', 'IN_PROGRESS')
      AND b.scheduled_start <
          TIMESTAMPTZ '2026-07-03 12:30:00+05:30'
      AND b.scheduled_end >
          TIMESTAMPTZ '2026-07-03 11:00:00+05:30'
  )

ORDER BY p.rating DESC NULLS LAST
LIMIT 10;
