#!/usr/bin/env bash
# Usage: bash scripts/run_cp4.sh
# Run from the root of YOUR DE_Project_2026 repo with large_data.zip in the root or ~/Downloads.
set -euo pipefail
cd "$(dirname "$0")/.."

required=(sql/01_schema.sql sql/02_load_data.sql sql/05_indexes.sql sql/06_optimized_queries.sql benchmarks/run_benchmark.sh benchmarks/results/optimized/summary.csv sql/08_partitioning.sql)
for f in "${required[@]}"; do
  if [[ ! -s "$f" ]]; then echo "ERROR: missing prerequisite $f. Finish DE CP3 first; no benchmark was run." >&2; exit 1; fi
done
command -v psql >/dev/null || { echo 'ERROR: psql missing. Add PostgreSQL bin/ to PATH.' >&2; exit 1; }
command -v createdb >/dev/null || { echo 'ERROR: createdb missing.' >&2; exit 1; }
pg_isready -q || { echo 'ERROR: PostgreSQL server not accepting local connections.' >&2; exit 1; }

if [[ ! -f large_data/bookings.csv ]]; then
  if [[ -f large_data.zip ]]; then archive=large_data.zip
  elif [[ -f "$HOME/Downloads/large_data.zip" ]]; then archive="$HOME/Downloads/large_data.zip"
  else echo 'ERROR: Save uploaded large_data.zip in repo root or ~/Downloads.' >&2; exit 1; fi
  unzip -q "$archive" -d .
fi

for name in cities service_categories services professionals customers pro_skills pro_availability bookings reschedules reviews payouts; do
  [[ -s "large_data/$name.csv" ]] || { echo "ERROR: missing large_data/$name.csv" >&2; exit 1; }
done

# Keep the 820 MB of uncompressed CSV files out of Git.
if ! git check-ignore -q large_data/bookings.csv; then
  printf '\n/large_data/\n' >> .gitignore
fi

# Refuse to overwrite an existing database. Re-use only with deliberate manual validation.
if psql -AtX -d postgres -c "SELECT 1 FROM pg_database WHERE datname='urban_company_large';" | grep -qx '1'; then
  echo "ERROR: urban_company_large already exists. This safe setup script will not overwrite it." >&2
  echo "If data is already loaded, benchmark manually after checking row counts." >&2
  exit 1
fi

echo 'Creating dedicated database (existing urban_company is untouched)...'
createdb urban_company_large
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -f sql/01_schema.sql

tmp_sql=$(mktemp)
trap 'rm -f "$tmp_sql"' EXIT
sed 's#seed_data/#large_data/#g' sql/02_load_data.sql > "$tmp_sql"
echo 'Loading actual faculty large CSV files...'
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -f "$tmp_sql"

echo 'Applying actual DE CP3 indexes and analyzing...'
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -f sql/05_indexes.sql
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -c 'ANALYZE;'

echo 'Verifying database contents...'
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -c 'SELECT COUNT(*) AS bookings FROM uc.bookings;'
psql -X -v ON_ERROR_STOP=1 -d urban_company_large -c 'SELECT COUNT(*) AS customers FROM uc.customers;'

mkdir -p benchmarks/results/large
# These are REAL EXPLAIN (ANALYZE, BUFFERS) runs on OPTIMIZED workload.
echo 'Running optimized workload (3 runs/query) on large database...'
bash benchmarks/run_benchmark.sh urban_company_large large 3 sql/06_optimized_queries.sql

# Database storage from the connected server, never invented numbers.
query="WITH s AS (
 SELECT COALESCE(SUM(pg_relation_size(c.oid)),0) AS heap_bytes,
        COALESCE(SUM(pg_indexes_size(c.oid)),0) AS index_bytes,
        COALESCE(SUM(pg_total_relation_size(c.oid)),0) AS total_table_bytes
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='uc' AND c.relkind IN ('r','p')
) SELECT current_database() AS database,pg_database_size(current_database()) AS database_bytes,
  heap_bytes,index_bytes,total_table_bytes FROM s;"
psql -X -v ON_ERROR_STOP=1 --csv -d urban_company_large -c "$query" > benchmarks/results/large/storage.csv
if psql -AtX -d postgres -c "SELECT 1 FROM pg_database WHERE datname='urban_company';" | grep -qx '1'; then
  psql -X -v ON_ERROR_STOP=1 --csv -d urban_company -c "$query" > benchmarks/results/large/seed_storage.csv
fi

# Isolated, transaction-scoped partition proof: uc.bookings not changed.
psql -X -P pager=off -v ON_ERROR_STOP=1 -d urban_company_large -f sql/08_partitioning.sql > benchmarks/results/large/partition_pruning.txt

python3 scripts/cp4_build_report.py
printf '\nSUCCESS: CP4 data load + large benchmark + report created locally.\n'
printf 'Review the report and git diff before committing.\n'
