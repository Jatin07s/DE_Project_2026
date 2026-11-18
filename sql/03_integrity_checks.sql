
SET search_path TO uc, public;

WITH actual(table_name, actual_rows) AS (
 SELECT 'cities',count(*) FROM cities UNION ALL
 SELECT 'service_categories',count(*) FROM service_categories UNION ALL
 SELECT 'services',count(*) FROM services UNION ALL
 SELECT 'professionals',count(*) FROM professionals UNION ALL
 SELECT 'pro_skills',count(*) FROM pro_skills UNION ALL
 SELECT 'pro_availability',count(*) FROM pro_availability UNION ALL
 SELECT 'customers',count(*) FROM customers UNION ALL
 SELECT 'bookings',count(*) FROM bookings UNION ALL
 SELECT 'reschedules',count(*) FROM reschedules UNION ALL
 SELECT 'reviews',count(*) FROM reviews UNION ALL
 SELECT 'payouts',count(*) FROM payouts
), expected(table_name,expected_rows) AS (
 VALUES ('cities',10),('service_categories',10),('services',60),
        ('professionals',2500),('pro_skills',5000),('pro_availability',70407),
        ('customers',40000),('bookings',150000),('reschedules',5391),
        ('reviews',76539),('payouts',27015)
)
SELECT a.table_name, e.expected_rows, a.actual_rows,
       (a.actual_rows=e.expected_rows) AS matches
FROM actual a JOIN expected e USING(table_name)
ORDER BY a.table_name;


SELECT count(*) AS overlapping_pairs
FROM bookings a JOIN bookings b
  ON a.pro_id=b.pro_id AND a.booking_id<b.booking_id
 AND a.scheduled_start < b.scheduled_end
 AND b.scheduled_start < a.scheduled_end
WHERE a.pro_id IS NOT NULL
  AND a.status IN ('ASSIGNED','IN_PROGRESS')
  AND b.status IN ('ASSIGNED','IN_PROGRESS');


SELECT count(*) AS completed_without_skill
FROM bookings b JOIN services s USING(service_id)
WHERE b.status='COMPLETED'
  AND NOT EXISTS (
    SELECT 1 FROM pro_skills ps
    WHERE ps.pro_id=b.pro_id AND ps.category_id=s.category_id
  );

SELECT count(*) AS jobs_outside_recorded_shift
FROM bookings b
JOIN pro_availability a
  ON a.pro_id=b.pro_id AND a.work_date=(b.scheduled_start AT TIME ZONE 'Asia/Kolkata')::date
WHERE b.status IN ('ASSIGNED','IN_PROGRESS','COMPLETED')
  AND ( (b.scheduled_start AT TIME ZONE 'Asia/Kolkata')::time < a.start_time
     OR (b.scheduled_end AT TIME ZONE 'Asia/Kolkata')::time > a.end_time
     OR (b.scheduled_end AT TIME ZONE 'Asia/Kolkata')::date <> a.work_date )
  AND a.work_date BETWEEN DATE '2026-06-01' AND DATE '2026-07-31';


SELECT count(*) AS missing_shift_record
FROM bookings b
WHERE b.pro_id IS NOT NULL
  AND (b.scheduled_start AT TIME ZONE 'Asia/Kolkata')::date
      BETWEEN DATE '2026-06-01' AND DATE '2026-07-31'
  AND NOT EXISTS (
    SELECT 1 FROM pro_availability a
    WHERE a.pro_id=b.pro_id
      AND a.work_date=(b.scheduled_start AT TIME ZONE 'Asia/Kolkata')::date
  );


SELECT count(*) AS invalid_payouts
FROM payouts
WHERE net_payout <> gross_earnings - commission
   OR EXTRACT(ISODOW FROM week_start) <> 1;


SELECT status, count(*) AS bookings,
       count(*) FILTER (WHERE pro_id IS NULL) AS without_pro,
       count(*) FILTER (WHERE started_at IS NULL) AS without_start,
       count(*) FILTER (WHERE completed_at IS NULL) AS without_completion,
       count(*) FILTER (WHERE tip IS NULL) AS without_tip
FROM bookings GROUP BY status ORDER BY status;
