# Omnichannel Marketing Attribution & ROAS Optimization Engine

A marketing attribution data warehouse built on PostgreSQL 16 and MongoDB 7.0. It ingests synthetic clickstream data (impressions, clicks, purchases, refunds) from Google, Meta, TikTok and Email, and applies multi-touch attribution models to calculate the true Return on Ad Spend (ROAS) per platform.

Last-click attribution gives 100% of the credit to the final touchpoint, which undervalues upper-funnel channels such as Meta and TikTok. This project distributes revenue credit across every touchpoint in a customer's journey instead.

> All data is synthetic. Results demonstrate the method, not real-world channel performance.

## Features

- Four attribution models in SQL: First-Touch, Last-Touch, Linear and Time-Decay (30-day lookback window)
- ROAS per platform and per model, computed from attributed net revenue and daily campaign spend
- Star schema with an EER specialization (Campaign into Paid and Email campaigns)
- Materialized views refreshed on a schedule with pg_cron
- Stored procedures and triggers for deduplicated ingestion, refund adjustment and auditing
- Pessimistic locking (`SELECT ... FOR UPDATE`) for concurrent budget updates
- Query tuning with `EXPLAIN ANALYZE`
- Extensions: MongoDB raw-event store, full-text search, replication, security (pgcrypto, SSL, roles), backup and recovery

## Tech stack

| Area | Tools |
|---|---|
| Databases | PostgreSQL 16, MongoDB 7.0 |
| Languages | SQL, PL/pgSQL, Python (Faker, Pandas, NumPy, Matplotlib) |
| Extensions | pg_cron, pgcrypto, SSL/TLS |
| Infrastructure | Docker Compose |

## Repository layout

```
.
├── core/                  # Core warehouse (Person A)
│   ├── sql/               # Schema, indexes, api views, models, procedures, triggers
│   ├── generator/         # Synthetic data generator (fixed random seed)
│   └── tests/             # Core smoke tests
├── ext/                   # Extension modules (Person B)
│   ├── mongodb/
│   ├── security/
│   ├── fts/
│   ├── replication/
│   ├── recovery/
│   └── qa/
├── docs/                  # ER/EER diagrams, synopsis, normalization notes, report
├── compose.core.yml       # PostgreSQL 16 with pg_cron
├── compose.ext.yml        # MongoDB, replica
├── Makefile
└── README.md
```

## Architecture rules

The project is split so the core always works, even if an extension breaks.

1. The core lives in the `core` schema and the extensions live in the `ext` schema. Nothing in `core` references `ext`.
2. Extensions read the core only through read-only `api_*` views (`api_touchpoints`, `api_conversions`, `api_roas`).
3. The core runs from `compose.core.yml`. Extension services run from `compose.ext.yml`.
4. The generator writes CSV for PostgreSQL and JSONL for MongoDB. The core loads only from CSV.
5. A fixed random seed regenerates identical data, so any module can be rebuilt from scratch.

## Getting started

Requirements: Docker, Docker Compose, Python 3.11+, make.

```bash
git clone <repo-url>
cd omnichannel-attribution

python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

make up          # start PostgreSQL (core)
make load        # generate data and load the schema and data
make test-core   # run core checks (credit sums to 100% per conversion)
```

Extensions are optional:

```bash
make up-ext      # start MongoDB and the replica
```

The Makefile targets above are planned and will be added as the core is built (see Status).

## Attribution models

| Model | Credit rule |
|---|---|
| First-Touch | 100% to the earliest touchpoint in the lookback window |
| Last-Touch | 100% to the latest touchpoint before the conversion |
| Linear | Equal share to every touchpoint in the window |
| Time-Decay | Weight decreases with the age of the touchpoint, normalized to 100% |

Each conversion's credit always sums to its revenue (net of refunds).

## Status

- [ ] Schema, ER and EER design
- [ ] Synthetic data generator
- [ ] Attribution models
- [ ] Materialized views and scheduling
- [ ] Procedures and triggers
- [ ] Concurrency and isolation demo
- [ ] Performance tuning report
- [ ] Extensions (MongoDB, security, full-text search, replication, recovery)
- [ ] Dashboard and final report

