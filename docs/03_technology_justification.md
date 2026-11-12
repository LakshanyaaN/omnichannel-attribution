# Technology Justification & Architectural Evaluation

This system combines **PostgreSQL 16** with **pgvector** and **MongoDB 7.0** to form a polyglot persistence architecture. Each engine was chosen to solve specific performance and data-modeling constraints.

---

## 1. Relational Data Warehouse: PostgreSQL 16

### Why PostgreSQL?
1. **Advanced Analytical SQL:** Multi-touch attribution requires window frames (`PARTITION BY ... ORDER BY ... ROWS BETWEEN`), mathematical exponential decay functions (`POWER(2.0, -delta_t / lambda)`), and recursive common table expressions (`WITH RECURSIVE`) to reconstruct customer journey paths. PostgreSQL provides one of the industry's most advanced SQL standard query planners.
2. **ACID Transaction Guarantees & Row-Level Locking:** Managing campaign budgets and tracking spend deductions requires strict consistency. PostgreSQL allows fine-grained pessimistic locking (`SELECT ... FOR UPDATE`) to prevent race conditions during high-volume ad bid adjustments.
3. **Automated Data Integrity:** Enforces relational integrity across facts and dimensions through composite foreign keys, cascading triggers (such as automated net revenue deduction upon refund issuance), and generated stored columns.

---

## 2. NoSQL Staging Store: MongoDB 7.0

### Why MongoDB?
1. **Schema Flexibility for Heterogeneous Clickstreams:** Digital ad platforms (Google Ads, Meta Graph API, TikTok Events API, SendGrid) emit telemetry in divergent JSON formats with nested query parameters, varying device contexts, and unexpected schema changes.
2. **High-Throughput Ingestion Buffer:** Enforcing rigid relational constraints at the point of ingestion risks dropping valid click events during unexpected payload mutations. MongoDB serves as an ELT (Extract, Load, Transform) staging zone where raw events land immediately and are cleansed downstream.
3. **Full Lifecycle (RUD) Management:** Administrators and automated jobs can query raw payloads, mutate processing flags or quarantine corrupted payloads, and purge compliance-bound records (GDPR Right to Be Forgotten) without affecting historical warehouse facts.

---

## 3. Vector Database: PostgreSQL `pgvector`

### Why `pgvector` over Dedicated Vector Databases (Pinecone/Milvus)?
1. **Co-located Metadata Filtering:** Marketing analysts need to search for similar ad creatives while simultaneously filtering by relational attributes (e.g., "Find ads similar to this copy *AND* belonging to active Meta campaigns *AND* run in Q3"). In standalone vector databases, this requires expensive cross-database federation.
2. **Operational Simplicity:** `pgvector` enables native vector types (`vector(384)`) and index algorithms (HNSW, IVFFlat) directly within the existing relational database, eliminating data duplication and synchronization lag.
