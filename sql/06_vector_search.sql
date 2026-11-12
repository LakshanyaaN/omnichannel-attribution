-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 06_vector_search.sql
-- Description: Semantic Vector Search and Hybrid Search using pgvector
--              (Rubric Components 4 & 9 - NoSQL / Vector Feature RUD).
-- ============================================================================

-- Ensure pgvector is active
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================================
-- 1. READ (VECTOR SEARCH): Semantic Similarity Queries
-- ============================================================================

-- 1.1 Pure Semantic Similarity Search (Cosine Distance <=> )
-- Finds the top 3 ad creatives most semantically similar to a reference ad
WITH reference_creative AS (
    SELECT headline, embedding 
    FROM dim_creative 
    WHERE headline LIKE '%Attribution%'
    LIMIT 1
)
SELECT 
    c.creative_id,
    c.headline,
    c.call_to_action,
    camp.channel,
    -- Cosine Similarity = 1 - Cosine Distance
    ROUND((1 - (c.embedding <=> ref.embedding))::NUMERIC, 4) AS cosine_similarity,
    -- Euclidean Distance (<->)
    ROUND((c.embedding <-> ref.embedding)::NUMERIC, 4) AS euclidean_distance
FROM dim_creative c
CROSS JOIN reference_creative ref
JOIN dim_campaign camp ON c.campaign_id = camp.campaign_id
WHERE c.headline <> ref.headline
ORDER BY c.embedding <=> ref.embedding ASC
LIMIT 3;

-- 1.2 Channel-Restricted Semantic Search
-- Marketers often ask: "Show me Meta creatives that say something similar to our top Google search ad"
WITH target_ad AS (
    SELECT embedding 
    FROM dim_creative c
    JOIN dim_campaign camp ON c.campaign_id = camp.campaign_id
    WHERE camp.channel = 'Google'
    LIMIT 1
)
SELECT 
    c.headline,
    c.body_text,
    camp.channel,
    ROUND((1 - (c.embedding <=> target.embedding))::NUMERIC, 4) AS similarity_score
FROM dim_creative c
JOIN dim_campaign camp ON c.campaign_id = camp.campaign_id
CROSS JOIN target_ad target
WHERE camp.channel = 'Meta'
ORDER BY c.embedding <=> target.embedding ASC
LIMIT 3;

-- ============================================================================
-- 2. HYBRID SEARCH: Keyword (TSVector) + Semantic (pgvector) Search
-- ============================================================================
-- Real-world search engines combine lexical exact-matching with semantic vectors.
-- 1. Filters candidates where keywords match using Full-Text Search.
-- 2. Reranks the candidates using dense vector similarity.

WITH query_context AS (
    SELECT 
        to_tsquery('english', 'attribution | spend | roas') AS lexical_query,
        (SELECT embedding FROM dim_creative LIMIT 1) AS semantic_vector
)
SELECT 
    c.creative_id,
    c.headline,
    camp.channel,
    -- Full-text keyword match rank
    ROUND(ts_rank(c.headline_tsv, qc.lexical_query)::NUMERIC, 4) AS keyword_rank,
    -- Semantic vector similarity
    ROUND((1 - (c.embedding <=> qc.semantic_vector))::NUMERIC, 4) AS vector_similarity,
    -- Combined Hybrid Score (70% semantic, 30% lexical)
    ROUND(
        (0.70 * (1 - (c.embedding <=> qc.semantic_vector)) + 
         0.30 * ts_rank(c.headline_tsv, qc.lexical_query))::NUMERIC, 
        4
    ) AS hybrid_score
FROM dim_creative c
CROSS JOIN query_context qc
JOIN dim_campaign camp ON c.campaign_id = camp.campaign_id
WHERE c.headline_tsv @@ qc.lexical_query
ORDER BY hybrid_score DESC
LIMIT 5;

-- ============================================================================
-- 3. UPDATE (VECTOR STORE): Re-embedding & Metadata Evolution
-- ============================================================================
-- When marketing teams refine ad copy, the dense vector embedding must be re-computed.

-- Demonstrating live update of creative headline and body
UPDATE dim_creative
SET headline = 'AI-Powered Omnichannel Multi-Touch Attribution Engine (Updated)',
    body_text = 'Real-time ROAS intelligence replacing legacy last-click models.'
WHERE creative_id = (SELECT creative_id FROM dim_creative LIMIT 1);

-- Verify the update
SELECT creative_id, headline, body_text, headline_tsv
FROM dim_creative
WHERE headline LIKE 'AI-Powered Omnichannel%';

-- ============================================================================
-- 4. DELETE (VECTOR STORE): Purging Obsolete / Test Embeddings
-- ============================================================================
-- Note: Live historical creatives referenced by fact_touchpoint are protected 
-- by FOREIGN KEY ... ON DELETE RESTRICT (preventing orphaned analytics).
-- To demonstrate DELETE, we insert an obsolete unreferenced vector creative and purge it:

INSERT INTO dim_creative (
    creative_id, campaign_id, headline, body_text, call_to_action, embedding
)
SELECT 
    'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    campaign_id,
    'Temporary Obsolete Vector Ad To Be Deleted',
    'Testing vector removal without violating touchpoint foreign keys.',
    'Delete Me',
    embedding
FROM dim_creative
LIMIT 1
ON CONFLICT (creative_id) DO NOTHING;

-- Execute the DELETE operation
DELETE FROM dim_creative
WHERE creative_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid;

-- Verify deletion succeeded (Count should be 0)
SELECT COUNT(*) AS remaining_temporary_creatives
FROM dim_creative
WHERE creative_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid;

-- ============================================================================
-- 5. PERFORMANCE EXPLAIN: HNSW Index Verification
-- ============================================================================
-- Proves that pgvector utilizes the Hierarchical Navigable Small World (HNSW) index
EXPLAIN (ANALYZE, BUFFERS)
SELECT creative_id, headline
FROM dim_creative
ORDER BY embedding <=> (SELECT embedding FROM dim_creative LIMIT 1)
LIMIT 5;
