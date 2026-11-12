# Omnichannel Marketing Attribution Engine & Analytics Warehouse

An enterprise-grade analytical data warehouse and attribution engine built to solve the multi-touch attribution problem in modern digital advertising. Designed for the PES University DBMS Experiential Learning curriculum (Units 1–4).

---

## 1. Problem Statement
Modern consumers rarely convert on their first interaction. A customer might discover a brand on **Meta**, compare alternatives on **TikTok**, read a promotional newsletter via **Email**, and finally purchase after clicking a **Google Search** ad. 

Traditional **last-click attribution** credits 100% of the sale to Google, severely undervaluing upper-funnel channels and causing misallocated marketing budgets. This engine models customer journeys and re-attributes conversion revenues across four mathematical attribution models:
- **First-Touch Attribution:** 100% credit to the initial discovery channel.
- **Last-Touch Attribution:** 100% credit to the final conversion touchpoint.
- **Linear Attribution:** Uniformly distributed credit across all eligible touchpoints.
- **Time-Decay Attribution:** Exponentially decays credit with a 7-day half-life based on temporal proximity to conversion.

---

## 2. System Architecture

```
                       [ Synthetic Data Generator ]
                                    |
                    +---------------+---------------+
                    | (Raw JSON)                    | (Clean Relational CSV)
                    v                               v
          [ MongoDB 7.0 ]                 [ PostgreSQL 16 (Star Schema) ]
       raw_clickstream_events                  |-- dim_user
        (Full RUD Operations)                  |-- dim_campaign (Paid & Email)
                                               |-- dim_creative (pgvector + FTS)
                                               |-- dim_date
                                               |-- fact_touchpoint
                                               |-- fact_conversion
                                               |-- fact_refund (Triggers)
                                               |-- fact_spend
                                                    |
                                          [ Advanced SQL Engine ]
                                          |-- Window Functions (4 Models)
                                          |-- Recursive CTE (Journeys)
                                          |-- Concurrency / Row-Locking
                                                    |
                                          [ Next.js 15 Web App ]
                                          |-- Role-Based Access (Analyst vs Manager)
                                          |-- Interactive ROAS Analytics
                                          |-- Semantic Vector Search
```

---

## 3. Technology Stack & Prerequisites

- **Relational OLAP Warehouse:** PostgreSQL 16 with `pgvector`
- **NoSQL Staging Store:** MongoDB 7.0
- **Frontend / Application Backend:** Next.js 15 (React 19, TypeScript, Tailwind CSS, Recharts)
- **Containerization:** Docker Compose
- **Programming & Data Ingestion:** Python 3.10+ (`pandas`, `numpy`, `faker`, `pymongo`, `psycopg2-binary`)

---

## 4. Quickstart

### 1. Clone the repository
```bash
git clone https://github.com/LakshanyaaN/omnichannel-attribution.git
cd omnichannel-attribution
```

### 2. Start PostgreSQL and MongoDB
```bash
docker compose up -d
```

### 3. Initialize Schema and Extensions
The schema and RBAC roles initialize automatically via scripts mounted into `/docker-entrypoint-initdb.d/`.

---

## 5. Academic Syllabus & Rubric Traceability

- **Unit 1:** Star Schema design, Relational Algebra, DDL with Keys, CHECK & UNIQUE constraints, Generated Columns.
- **Unit 2:** Window functions (`FIRST_VALUE`, `SUM() OVER`), Recursive CTE (journey paths), Correlated subqueries, Multi-table joins, Triggers (`trg_deduct_refund`), Stored Procedures (`sp_ingest_touchpoints`), Full-Text Search.
- **Unit 3:** Functional dependencies, Normalization to BCNF, Query optimization with `EXPLAIN (ANALYZE, BUFFERS)` and composite index tuning.
- **Unit 4:** Pessimistic row-locking (`SELECT FOR UPDATE`), MongoDB document modeling with full **RUD**, Semantic Vector Search with `pgvector`, and Next.js full-stack app with dual-role database-enforced RBAC.
