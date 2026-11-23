#!/usr/bin/env python3
"""Build a REAL-NUMBERS CP4 report from faculty benchmark outputs; never invent timings."""
from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OPT = ROOT / 'benchmarks/results/optimized'
LARGE = ROOT / 'benchmarks/results/large'
OUT = ROOT / 'docs/05_scalability_report.md'
QUERY_IDS = [f'R{i:02}' for i in range(1, 26)] + [f'W{i:02}' for i in range(1, 6)]
TIMING = re.compile(r'Execution Time:\s*([0-9]+(?:\.[0-9]+)?)\s*ms')


def load_summary(folder: Path) -> dict[str, dict]:
    p = folder / 'summary.csv'
    if not p.is_file():
        raise ValueError(f'Missing measured data: {p}')
    with p.open(newline='') as fp:
        reader = csv.DictReader(fp)
        need = {'query_id', 'type', 'avg_ms'}
        if not need.issubset(reader.fieldnames or []):
            raise ValueError(f'Missing CSV columns in {p}: {need - set(reader.fieldnames or [])}')
        rows = list(reader)
    if len(rows) != 30 or {r['query_id'] for r in rows} != set(QUERY_IDS):
        raise ValueError(f'{p} must have exactly one row for each of R01–R25, W01–W05')
    out = {}
    for row in rows:
        ident = row['query_id']
        avg = float(row['avg_ms'])
        if avg < 0:
            raise ValueError(f'{p}: negative time for {ident}')
        raw_path = folder / f'{ident}.txt'
        if not raw_path.is_file():
            raise ValueError(f'Missing raw EXPLAIN plan: {raw_path}')
        times = [float(x) for x in TIMING.findall(raw_path.read_text(errors='replace'))]
        if len(times) < 3:
            raise ValueError(f'{raw_path}: only {len(times)} real execution times, need >=3')
        calculated = sum(times) / len(times)
        if abs(calculated - avg) > 0.011:
            raise ValueError(f'{ident}: summary {avg:.3f} != mean of {len(times)} raw times {calculated:.3f}')
        row['_avg'] = avg
        row['_runs'] = len(times)
        out[ident] = row
    return out


def storage(path: Path):
    if not path.exists():
        return None
    with path.open(newline='') as f:
        rows = list(csv.DictReader(f))
    return rows[0] if rows else None


def human_bytes(s):
    value = int(s)
    for unit in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if value < 1024 or unit == 'TiB':
            return f'{value:.1f} {unit}' if unit != 'B' else f'{value} B'
        value /= 1024


def growth_category(ratio: float):
    if ratio <= 3:
        return 'Near-stable (≤3×)'
    if 10 <= ratio <= 30:
        return 'Roughly proportional (~20×)'
    if ratio > 30:
        return 'Superlinear (>30×)'
    return 'Intermediate (3–10×)'


def main() -> None:
    before = load_summary(OPT)
    after = load_summary(LARGE)
    for q in QUERY_IDS:
        if before[q]['type'] != after[q]['type']:
            raise ValueError(f'{q}: query type mismatch across benchmark phases')

    total_large = LARGE / 'partition_pruning.txt'
    if not total_large.exists() or not all(s in total_large.read_text(errors='replace') for s in ['ROLLBACK', 'QUERY PLAN']):
        raise ValueError('Missing completed partition proof (ROLLBACK and QUERY PLAN expected).')

    pgvers = subprocess.run(['psql', '--version'], capture_output=True, text=True, check=False).stdout.strip() or 'record PostgreSQL version manually'
    lines = [
        '# CP4 — Scalability Report: Urban Company Home Services', '',
        f'- Recorded: {datetime.now().astimezone():%Y-%m-%d %H:%M %Z}',
        f'- PostgreSQL client: {pgvers}',
        '- Dataset: faculty-provided `large_data.zip`, 11 CSVs; 3,000,000 bookings and 800,000 customers (archive row counts).',
        '- Reference: CP3 `benchmarks/results/optimized/summary.csv` on original dataset (150,000 bookings).',
        '- Scale test: `benchmarks/results/large/summary.csv` using CP3 optimized workload, with 3 measured runs/query.',
        '- Method: `EXPLAIN (ANALYZE, BUFFERS)`; WRITE statements are wrapped in BEGIN/ROLLBACK by faculty benchmark script.',
        '- Raw execution plans are stored in both result folders; averages are independently checked against raw plans.',
        '', '## 1. Actual large-dataset performance (all 30 queries)', '',
        '| Query | Type | Optimized seed avg (ms) | Large avg (ms) | Time growth | Scan nodes on large data |',
        '|---|---|---:|---:|---:|---|',
    ]
    relative = []
    for q in QUERY_IDS:
        a, b = before[q]['_avg'], after[q]['_avg']
        ratio = (b / a) if a > 0 else None
        ratio_label = f'{ratio:.2f}×' if ratio is not None else 'N/A (seed avg=0)'
        nodes = (after[q].get('scan_nodes') or '').replace('|', '\\|').replace('\n', ' ')
        lines.append(f'| {q} | {after[q]["type"]} | {a:.3f} | {b:.3f} | {ratio_label} | {nodes} |')
        if ratio is not None:
            relative.append((ratio, q, a, b))
    lines.extend(['', '## 2. Growth analysis', '',
                  'The table above compares measured execution time, not row count. The fact that bookings increased 20× does not mean every query must become 20× slower.', '',
                  '| Growth category | Queries (calculated from measured timings) |',
                  '|---|---|'])
    buckets = {}
    for ratio, q, _, _ in relative:
        buckets.setdefault(growth_category(ratio), []).append(q)
    for cat in ['Near-stable (≤3×)', 'Intermediate (3–10×)', 'Roughly proportional (~20×)', 'Superlinear (>30×)']:
        lines.append(f'| {cat} | {", ".join(buckets.get(cat, [])) or "None"} |')
    lines += ['', '### Five biggest large-data regressions', '',
              '| Query | Seed avg (ms) | Large avg (ms) | Growth | Investigation priority |',
              '|---|---:|---:|---:|---|']
    for ratio, q, a, b in sorted(relative, reverse=True)[:5]:
        lines.append(f'| {q} | {a:.3f} | {b:.3f} | {ratio:.2f}× | Inspect `benchmarks/results/large/{q}.txt` for scan, join, sort and buffer costs |')

    large_storage = storage(LARGE / 'storage.csv')
    seed_storage = storage(LARGE / 'seed_storage.csv')
    lines += ['', '## 3. Measured database storage', '',
              '| Database | DB size | Table heap size (uc schema) | Index size (uc schema) | Total table storage (uc schema) |',
              '|---|---:|---:|---:|---:|']
    for s in [seed_storage, large_storage]:
        if s:
            lines.append(f'| {s["database"]} | {human_bytes(s["database_bytes"])} | {human_bytes(s["heap_bytes"])} | {human_bytes(s["index_bytes"])} | {human_bytes(s["total_table_bytes"])} |')
    if not seed_storage:
        lines += ['', '*Seed database storage not collected on this machine; no number is substituted.*']

    lines += ['', '## 4. Partitioning proof and production constraints', '',
              '- `sql/08_partitioning.sql` demonstrates `RANGE (booked_at)` for `uc.bookings` in a transaction-scoped prototype.',
              '- The demo uses an approximately 1% **sample only** to illustrate partition pruning. All 30 large benchmark queries run on the full original `uc.bookings`, not the sample.',
              '- The captured execution plan and partition names are in `benchmarks/results/large/partition_pruning.txt`.',
              '- A PostgreSQL partitioned PRIMARY KEY or UNIQUE constraint must include the partition column `booked_at`. The original single-column `booking_id` key and referencing foreign keys cannot simply be copied over.',
              '- Production migration requires FK redesign (e.g., composite references or a separate globally unique booking-identity table), partition-aware query predicates, and comparison tests before cutover.',
              '- A query filtering `scheduled_start` without `booked_at` may not prune `booked_at` partitions; test actual query patterns before committing to this choice.',
              '', '## 5. 100× scaling architecture — proposal (not benchmarked)', '',
              '- **Partitioning:** Start with monthly or quarterly RANGE partitions on `booked_at`, only if the major access paths include compatible date ranges. Archive old partitions and keep indexes local.',
              '- **Sharding:** A `customer_id` hash key helps customer-history lookups, but city-level dashboards, professional schedules and payouts may cross shards; a city-oriented key has the opposite trade-off and risks uneven load. Keep booking, payments and reviews co-located by a stable routing key where possible; use a cross-shard analytics pipeline.',
              '- **Read replicas:** Route stale-tolerant read-heavy reporting and historical aggregations to replicas. Keep availability confirmation, live booking state transitions, payment/update operations and read-after-write critical flows on primary.',
              '- **Caching:** Cache relatively stable service catalogs and category lists with explicit invalidation. Do not serve payment or immediately changing booking state from stale caches.',
              '- **Maintenance:** Monitor autovacuum bloat, dead tuples, index growth, replication lag and slow queries; run ANALYZE after bulk loads. Consider partition retention and refreshable aggregate tables for multi-year analytics.',
              '', '## 6. Scale-only issues and follow-up tests', '',
              'The five regressions in section 2 are **measured candidates** for investigation, not proven root causes. For each candidate, compare relevant `EXPLAIN` nodes with optimized-seed raw plans and document whether the slowdown came from full scans, poor estimates, sort spills, join choice, or increased result cardinality.',
              '', '**Required manual validation before declaring targets met:**', '',
              '- [ ] Check faculty-defined latency targets in your project `README.md`, classify each query as PASS/FAIL using measured large avg.',
              '- [ ] For a scale-only issue, record relevant before/after plan lines and verify any fix with fresh real benchmark output.',
              '- [ ] Confirm the optimized SQL results have the same semantics on large data; fix any CP3-dependent query issues, especially NULL-sensitive logic.',
              '- [ ] Review the `booked_at` partitioning demo plan to verify pruning, and explain why this prototype is not a production migration.',
              '', '## 7. Conclusion', '',
              'The 30-query large-dataset measurement and growth comparison above provide a factual basis for assessing scalability. Production readiness is **not asserted** until service-level targets, critical correctness checks, and the proposed scale-only fixes are verified. Remaining risks include cross-shard joins, FK changes under partitioning, skew, stale replicas and index-maintenance cost.', '']

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('\n'.join(lines), encoding='utf-8')
    print(f'OK: {OUT.relative_to(ROOT)} generated from 30 pairs of measured summary rows and validated raw plan timings.')
    print('Review TODO boxes and evidence-based limitations before final submission.')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        sys.exit('ERROR: ' + str(exc))
