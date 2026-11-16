# CP1 · Problem Understanding — Urban Company Home Services

**Scope:** Reconstruct the PostgreSQL 15+ schema from the 11 seed-data CSV exports, preserve the faculty's 30-query workload, and document stakeholder needs. This phase covers *data correctness and schema design*, not query tuning.

| ID | Business need (in our words) | Primary stakeholder(s) | Workload | Classification |
|---|---|---|---|---|
| P1 | Return an up-to-date service catalogue and available appointment slots without showing unskilled, unavailable or double-booked professionals. | Customers; scheduling team | R01, R02, W01 | Customer-facing / real-time |
| P2 | Retrieve a customer's bookings, details and contact record quickly so users and support can resolve questions. | Customers; support | R03, R06, R22, R23 | Customer-facing / real-time (including interactive support) |
| P3 | Show a partner today's jobs and earnings, and record job completion reliably while in the field. | Service professionals | R04, R07, W03 | Customer-facing / real-time (partner app) |
| P4 | Find imminent unassigned jobs, assign a suitable professional and flag missed appointments quickly. | Dispatch; operations | R05, W02, W05 | Operational / real-time |
| P5 | Identify active professionals without customer-cancelled bookings for rewards; avoid misleading empty results. | Partner success / rewards | R13 | Reporting / analytics |
| P6 | Measure lateness, no-shows, poor reviews and unskilled assignments to protect service quality. | Quality / compliance | R09, R10, R15, R18, R21 | Reporting / analytics |
| P7 | Summarize weekly payouts, membership discounts, fees and gross merchandise value accurately and efficiently. | Finance; UC Plus | R08, R12, R20, R24, W04 | Reporting / analytics; W04 is a batch write |
| P8 | Understand demand by time and region, retention and professional utilisation; prepare for 20× booking growth. | Operations; city expansion | R11, R14, R16, R17, R19, R25 | Reporting / analytics |

## Assumptions and boundaries

- A customer can create many bookings; a booking chooses one service and city and can have **no professional yet** (`pro_id` is nullable).
- A professional can have many skills and many daily availability rows. Availability records and certifications are distinct entities.
- Reviews are optional and there is at most one review record per booking in the supplied export.
- Rescheduling history is one-to-many: one booking may be rescheduled multiple times.
- Payouts are weekly professional-level accounting snapshots; financial and rating aggregates may deliberately repeat information stored in bookings/reviews.
- The distinct statuses and nullable fields have been checked against all provided CSV records. No additional indexes are introduced in CP1.
- For CP1, only PK, FK, UNIQUE, NOT NULL and CHECK constraints (including their implicit PK/UNIQUE indexes) are permitted. Extra performance indexes belong to CP3.

**Evidence:** The supplied `seed_data.zip` was audited offline (376,932 CSV rows across 11 tables). A local PostgreSQL import remains to be run for final verification.
