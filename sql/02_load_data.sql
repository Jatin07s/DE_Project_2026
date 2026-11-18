

\set ON_ERROR_STOP on
SET search_path TO uc, public;
BEGIN;


\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy service_categories FROM 'seed_data/service_categories.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy services FROM 'seed_data/services.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy professionals FROM 'seed_data/professionals.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy pro_skills FROM 'seed_data/pro_skills.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy pro_availability FROM 'seed_data/pro_availability.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy bookings FROM 'seed_data/bookings.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy reschedules FROM 'seed_data/reschedules.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy reviews FROM 'seed_data/reviews.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy payouts FROM 'seed_data/payouts.csv' WITH (FORMAT csv, HEADER true, NULL '')

COMMIT;
ANALYZE;
