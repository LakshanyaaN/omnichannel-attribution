-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 08_query_optimization_demo.sql
-- Description: Query Optimization, Index Scan Profiling, Buffer Hits, and
--              Execution Plan Analysis with EXPLAIN ANALYZE (Unit 3).
-- ============================================================================

-- ============================================================================
-- 1. PROFILING THE CORE ATTRIBUTION ENGINE (WINDOW FUNCTIONS)
-- ============================================================================
-- Analyzes execution of eligible touchpoint discovery, 30-day window joins,
-- and four attribution weights.
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING, SUMMARY)
WITH eligible_touchpoints AS (
    SELECT 
        c.conversion_id,
        c.net_revenue,
        t.touchpoint_id,
        t.campaign_id,
        ROW_NUMBER() OVER (PARTITION BY c.conversion_id ORDER BY t.touchpoint_ts ASC) AS seq_asc,
        ROW_NUMBER() OVER (PARTITION BY c.conversion_id ORDER BY t.touchpoint_ts DESC) AS seq_desc,
        COUNT(*) OVER (PARTITION BY c.conversion_id) AS total_touches,
        POWER(2.0, - EXTRACT(EPOCH FROM (c.conversion_ts - t.touchpoint_ts)) / 604800.0) AS raw_decay
    FROM fact_conversion c
    INNER JOIN fact_touchpoint t 
        ON c.user_id = t.user_id 
       AND t.touchpoint_ts >= (c.conversion_ts - INTERVAL '30 days')
       AND t.touchpoint_ts <= c.conversion_ts
)
SELECT 
    campaign_id,
    ROUND(SUM(CASE WHEN seq_asc = 1 THEN net_revenue ELSE 0 END), 2) AS first_touch_revenue,
    ROUND(SUM(CASE WHEN seq_desc = 1 THEN net_revenue ELSE 0 END), 2) AS last_touch_revenue,
    ROUND(SUM(net_revenue / total_touches), 2) AS linear_revenue,
    ROUND(SUM(net_revenue * (raw_decay / NULLIF(SUM(raw_decay) OVER (PARTITION BY conversion_id), 0))), 2) AS decay_revenue
FROM eligible_touchpoints
GROUP BY campaign_id;

-- ============================================================================
-- 2. PROFILING THE RECURSIVE CTE (CUSTOMER JOURNEY PATH TRAVERSAL)
-- ============================================================================
-- Shows WorkTable Scan, recursion depth, and join node behavior
EXPLAIN (ANALYZE, BUFFERS)
SELECT conversion_id, full_journey_path, total_touchpoints
FROM view_customer_journey_paths
LIMIT 20;

-- ============================================================================
-- 3. PROFILING COMPOSITE INDEX UTILIZATION
-- ============================================================================
-- Verifies that the planner utilizes idx_touchpoint_user_ts (Index Scan)
-- rather than scanning the entire fact table (Seq Scan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    user_id, 
    COUNT(*) AS total_interactions, 
    SUM(cost) AS total_user_cost
FROM fact_touchpoint
WHERE user_id = (SELECT user_id FROM dim_user LIMIT 1)
  AND touchpoint_ts >= '2026-03-01'
GROUP BY user_id;

-- ============================================================================
-- 4. PROFILING MATERIALIZED VIEW ROAS RETRIEVAL
-- ============================================================================
-- Proves constant-time O(1) index retrieval from pre-aggregated analytical view
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_channel_roas_comparison WHERE channel = 'Google';
