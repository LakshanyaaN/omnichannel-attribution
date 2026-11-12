# Next-Gen Data Management: NoSQL & Vector Search (Unit 4)

This document details the architectural design, mathematical foundations, and operational implementations for **NoSQL Document Storage (MongoDB 7.0)** and **Vector Search (PostgreSQL `pgvector`)** fulfilling **Rubric Components 4 and 9 (11 Marks Total)**.

---

## 1. NoSQL Staging Store: MongoDB 7.0 (Rubric Component 4)

### 1.1 Document Data Modeling
In multi-channel marketing, ad networks (Meta Graph API, Google Ads API, TikTok Webhooks, SendGrid) deliver clickstream payloads with heterogeneous schemas and deeply nested client contexts. 

Forcing these payloads directly into a rigid relational schema causes pipeline failures whenever an ad network introduces new telemetry fields or sends malformed UTM parameters.

#### Schema Structure (`raw_clickstream_events`):
```json
{
  "_id": { "$oid": "67333..." },
  "session_id": "sess_8109bf21a0",
  "user_id": "7b8d4e92-...",
  "platform": "Meta",
  "event_type": "CLICK",
  "cost": 1.85,
  "timestamp": "2026-03-15T14:30:00",
  "payload": {
    "ip": "198.51.100.42",
    "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)...",
    "utm_source": "meta",
    "utm_campaign": "c100a000-...",
    "utm_content": "cr00a000-...",
    "device": "iOS"
  },
  "status": "PROCESSED",
  "received_at": "2026-03-15T14:30:01.102Z"
}
```

### 1.2 Performance Indexing
MongoDB collections are indexed to optimize high-throughput queries:
- `db.raw_clickstream_events.createIndex({ session_id: 1 })`
- `db.raw_clickstream_events.createIndex({ received_at: -1 })`
- `db.raw_clickstream_events.createIndex({ platform: 1, event_type: 1 })`

---

## 2. NoSQL & Vector Feature RUD Implementation (Rubric Component 9 — 7 Marks)

The evaluation rubric explicitly requires demonstrating **Read, Update, and Delete (RUD)** on the NoSQL and Vector layers:

| Layer | Operation | Implementation | Script / SQL Reference |
|---|---|---|---|
| **MongoDB** | **Read (R)** | Querying raw events filtered by platform, cost range, and nested fields (`payload.device`). | `test_mongodb_rud()` in `tests/03_nosql_vector_rud_test.py` |
| **MongoDB** | **Update (U)** | In-place atomic mutations using `$set` (fraud flag), `$inc` (retry counts), and `$currentDate`. | `test_mongodb_rud()` in `tests/03_nosql_vector_rud_test.py` |
| **MongoDB** | **Delete (D)** | Purging quarantined bot clicks and test payloads (`delete_one`, `delete_many`). | `test_mongodb_rud()` in `tests/03_nosql_vector_rud_test.py` |
| **MongoDB** | **Aggregation** | 4-stage pipeline (`$match`, `$group`, `$sort`, `$project`) aggregating click spend and device breakdowns. | `data/mongo_analytics.py` |
| **pgvector** | **Read (R)** | Nearest-neighbor semantic search using Cosine Distance (`<=>`) to find similar ad creative headlines. | `sql/06_vector_search.sql` |
| **pgvector** | **Update (U)** | Updating dense 384-dimensional vector embeddings in-place when creative ad copy evolves. | `test_pgvector_rud()` in `tests/03_nosql_vector_rud_test.py` |
| **pgvector** | **Delete (D)** | Cascading deletion of obsolete vector representations and associated campaign metadata. | `sql/06_vector_search.sql` |

---

## 3. Vector Database Foundations & Mathematics

### 3.1 Mathematical Distance Metrics in `pgvector`
Each ad creative headline is encoded into a 384-dimensional dense vector $\vec{u} \in \mathbb{R}^{384}$. Similarity is evaluated using:

1. **Cosine Distance (`<=>`):**
   $$\text{CosineDistance}(\vec{u}, \vec{v}) = 1 - \frac{\vec{u} \cdot \vec{v}}{\|\vec{u}\|_2 \|\vec{v}\|_2}$$
   *Normalized vectors yield $\text{Cosine Similarity} = 1 - \text{Distance}$, bounded in $[0, 1]$.*

2. **Euclidean / L2 Distance (`<->`):**
   $$\text{L2Distance}(\vec{u}, \vec{v}) = \sqrt{\sum_{i=1}^{384} (u_i - v_i)^2}$$

3. **Negative Inner Product (`<#>`):**
   $$\text{InnerProduct}(\vec{u}, \vec{v}) = - (\vec{u} \cdot \vec{v})$$

### 3.2 Approximate Nearest Neighbor (ANN) Indexing: HNSW
Standard relational indexes (B-Trees) cannot index multi-dimensional vector spaces. PostgreSQL `pgvector` uses **HNSW (Hierarchical Navigable Small World)**:
- Constructs a multi-layer graph where bottom layers contain all vectors and top layers contain long-range skip links.
- Search traverses the sparse top layers to find the local neighborhood, then descends to dense lower layers to locate the exact nearest neighbors in $O(\log N)$ time.
- Configured in our warehouse via:
  ```sql
  CREATE INDEX idx_creative_embedding ON dim_creative USING hnsw (embedding vector_cosine_ops);
  ```

---

## 4. Hybrid Search Architecture

Pure vector search captures semantic intent but struggles with exact acronyms or specific product codes. Pure full-text search matches exact keywords but misses synonyms.

Our warehouse implements **Hybrid Search** (`sql/06_vector_search.sql`):
1. **Candidate Retrieval:** Filters rows where `headline_tsv @@ to_tsquery('english', '...')` matches lexical terms.
2. **Dense Reranking:** Calculates the vector cosine distance against the user's semantic query vector.
3. **Linear Score Blending:**
   $$\text{Score}_{\text{Hybrid}} = 0.70 \times \text{Similarity}_{\text{Vector}} + 0.30 \times \text{Rank}_{\text{BM25}}$$
