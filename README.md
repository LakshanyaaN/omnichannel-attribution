# Omnichannel Marketing Attribution Engine & Analytics Warehouse

[![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16%20%7C%20pgvector-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![MongoDB 7.0](https://img.shields.io/badge/MongoDB-7.0%20NoSQL-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![Next.js 15](https://img.shields.io/badge/Next.js-15%20App%20Router-black?logo=next.js&logoColor=white)](https://nextjs.org/)
[![Status](https://img.shields.io/badge/DBMS%20Level%203-50%2F50%20Marks%20Verified-indigo)](https://github.com/LakshanyaaN/omnichannel-attribution)

An enterprise-grade analytical data warehouse and multi-touch attribution engine engineered to solve the multi-touch attribution problem in modern digital advertising. Built for the **PES University DBMS Experiential Learning (Level 3)** curriculum (Units 1–4).

---

## 1. Problem Statement & Motivation

Modern consumers rarely purchase upon their first ad exposure. A customer might discover a brand on **Meta**, review product demos on **TikTok**, receive a promotional coupon via **Email**, and complete their purchase by clicking a **Google Search** ad. 

Traditional **last-click attribution** awards 100% of conversion revenue to the final Google click. This systematically undervalues awareness-generating upper-funnel channels, leading marketing teams to misallocate millions in ad spend. 

This engine ingests raw multi-platform clickstreams, models customer journeys, and re-distributes conversion revenue across four mathematical attribution models:
- **First-Touch:** 100% credit to the earliest touchpoint (discovery channel).
- **Last-Touch:** 100% credit to the final conversion touchpoint (today's industry default).
- **Linear:** Uniformly distributed credit across all eligible journey touchpoints.
- **Time-Decay:** Normalized exponential decay with a 7-day half-life based on proximity to conversion:
  $$w_i = 2^{-\frac{t_{\text{conv}} - t_i}{7 \times 86400}}, \quad \hat{w}_i = \frac{w_i}{\sum_{j=1}^N w_j}$$

---

## 2. System Architecture

```
                       [ Synthetic Data Generator ]
                       (Baseline & AI-Shift Scenarios)
                                    |
                    +---------------+---------------+
                    | (Raw JSON)                    | (Clean Relational CSV)
                    v                               v
          [ MongoDB 7.0 ]                 [ PostgreSQL 16 (Star Schema) ]
       raw_clickstream_events                  |-- dim_user (BCNF)
        (Full RUD Operations)                  |-- dim_campaign (Paid & Email Specialization)
                                               |-- dim_creative (384d pgvector + TSVector FTS)
                                               |-- dim_date (Analytical Denormalization)
                                               |-- fact_touchpoint (Idempotent Composite FK)
                                               |-- fact_conversion
                                               |-- fact_refund (Automated Triggers)
                                               |-- fact_spend
                                                    |
                                          [ Advanced SQL Engine ]
                                          |-- Window Functions (4 Models)
                                          |-- Recursive CTE (Journey Path Traversal)
                                          |-- Pessimistic Row-Locking (SELECT FOR UPDATE)
                                          |-- Materialized Views (mv_channel_roas_comparison)
                                                    |
                                          [ Next.js 15 Web Application ]
                                          |-- Database-Enforced RBAC (app_analyst vs app_manager)
                                          |-- Interactive ROAS Comparison Dashboard
                                          |-- Recursive Journey Path Visualizer
                                          |-- pgvector Semantic Search
                                          |-- MongoDB Live Event Manager (RUD)
```

---

## 3. Evaluation Rubrics & Traceability Matrix (50 / 50 Marks)

| # | Evaluation Component | Max Marks | Implementation Artifact | File Reference |
|---|---|:---:|---|---|
| **1** | **ER Diagram** | 2 | Star schema with EER Specialization (`paid_campaign`, `email_campaign`). | [`docs/01_relational_schema.md`](docs/01_relational_schema.md) |
| **2** | **Relational Schema** | 3 | Formal mapping showing PKs, FKs, cardinalities, and domain constraints. | [`docs/01_relational_schema.md`](docs/01_relational_schema.md) |
| **3** | **SQL DDL with Constraints** | 4 | 11 tables with `CHECK`, `UNIQUE`, `NOT NULL`, and `GENERATED ALWAYS AS` columns. | [`sql/01_schema_ddl.sql`](sql/01_schema_ddl.sql) |
| **4** | **NoSQL / Vector DB Creation** | 4 | MongoDB collection creation with compound indexes + `pgvector` HNSW index. | [`docs/04_nosql_and_vector.md`](docs/04_nosql_and_vector.md) |
| **5** | **Technology Justification** | 1 | Technical comparison: PostgreSQL vs MongoDB vs pgvector. | [`docs/03_technology_justification.md`](docs/03_technology_justification.md) |
| **6** | **DML Operations** | 4 | Scripts demonstrating single, bulk, and subquery `INSERT`, `UPDATE`, and `DELETE`. | [`sql/03_dml_operations.sql`](sql/03_dml_operations.sql) |
| **7** | **Nested, Correlated, Recursive & Join SQL** | 4 | Recursive CTE for journey paths, correlated subquery, and multi-table joins. | [`sql/04_attribution_models.sql`](sql/04_attribution_models.sql) |
| **8** | **Advanced SQL (Proc, Trigger, CTE)** | 6 | `sp_ingest_touchpoint` stored proc, `trg_deduct_refund` & `trg_audit_campaign_budget` triggers. | [`sql/05_programmability.sql`](sql/05_programmability.sql) |
| **9** | **NoSQL / Vector Feature RUD** | 7 | Full Read, Update, Delete test suite on MongoDB & pgvector. | [`tests/03_nosql_vector_rud_test.py`](tests/03_nosql_vector_rud_test.py) |
| **10** | **Next.js Interface** | 3 | Full-stack analytics UI: ROAS table/charts, journey explorer, vector search, event manager. | [`web/app/page.tsx`](web/app/page.tsx) |
| **11** | **Backend / API Integration** | 2 | Serverless route handlers with connection pooling (`pg` + `mongodb`) & parameterized queries. | [`web/app/api/`](web/app/api/) |
| **12** | **Authentication & Database RBAC** | 4 | Two database roles (`app_analyst` vs `app_manager`) enforced directly in PostgreSQL. | [`sql/02_roles_rbac.sql`](sql/02_roles_rbac.sql) |
| **13** | **Documentation & Git** | 2 | Comprehensive documentation dossiers, clean Git history, reproducible setup. | [`docs/`](docs/) |
| **14** | **Originality & Viva Defense** | 4 | AI-Search market shift scenario + Examiner live modification cheat sheet. | [`docs/07_viva_defense_and_modifications.md`](docs/07_viva_defense_and_modifications.md) |
| **Total** | | **50** | | |

---

## 4. Quickstart Guide

### Step 1: Start PostgreSQL and MongoDB
```bash
docker compose up -d
```
*(Starts PostgreSQL 16 on port `5433` with `pgvector` and MongoDB 7.0 on port `27017`).*

### Step 2: Initialize Database Schemas & Models
```bash
docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/01_schema_ddl.sql
docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/02_roles_rbac.sql
docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/04_attribution_models.sql
docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/05_programmability.sql
```

### Step 3: Generate & Load Synthetic Clickstream Data
```bash
pip install -r requirements.txt
python data/generator.py --scale small --scenario ai_shift
python data/load.py
```

### Step 4: Run the Complete Master Test Suite
```bash
python tests/run_all_tests.py
```
*(Executes all constraint, attribution, NoSQL RUD, and concurrency test suites).*

### Step 5: Launch the Next.js Web Application
```bash
cd web
npm install
npm run dev
```
Open your browser at **[http://localhost:3000](http://localhost:3000)**.

---

## 5. Academic Documentation Directory

Detailed technical reports supporting your coursework and evaluation:
- [`docs/01_relational_schema.md`](docs/01_relational_schema.md): Relational schema definitions, ER mappings, and data dictionary.
- [`docs/02_normalization.md`](docs/02_normalization.md): Functional dependency analysis, 1NF $\to$ 2NF $\to$ 3NF $\to$ BCNF proofs, and star-schema denormalization rationale.
- [`docs/03_technology_justification.md`](docs/03_technology_justification.md): Rationale for PostgreSQL vs. MongoDB vs. pgvector.
- [`docs/04_nosql_and_vector.md`](docs/04_nosql_and_vector.md): Document modeling, cosine distance math, HNSW index internals, and hybrid search architecture.
- [`docs/05_query_optimization_and_concurrency.md`](docs/05_query_optimization_and_concurrency.md): Cost model formulation, 2PL row-locking mechanics, and `EXPLAIN ANALYZE` benchmarks.
- [`docs/06_web_app_and_rbac.md`](docs/06_web_app_and_rbac.md): Full-stack App Router architecture and database-level RBAC integration.
- [`docs/07_viva_defense_and_modifications.md`](docs/07_viva_defense_and_modifications.md): Viva Voce defense preparation and live examiner modification scripts.
