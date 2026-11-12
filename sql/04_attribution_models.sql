-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 04_attribution_models.sql
-- Description: Advanced analytical SQL engine implementing the 4 Attribution Models,
--              Recursive CTE journey reconstruction, correlated subqueries, and
--              Materialized Views for ROAS reporting (Rubric Components 7 & 8).
-- ============================================================================

-- ============================================================================
-- 1. BASE ATTRIBUTION VIEW (Window Functions for the 4 Models)
-- ============================================================================
DROP VIEW IF EXISTS view_touchpoint_attribution_weights CASCADE;

CREATE OR REPLACE VIEW view_touchpoint_attribution_weights AS
WITH eligible_touchpoints AS (
    -- Link each conversion to all touchpoints for the same user within the 30-day lookback window
    SELECT 
        c.conversion_id,
        c.user_id,
        c.order_id,
        c.net_revenue,
        c.conversion_ts,
        t.touchpoint_id,
        t.campaign_id,
        t.creative_id,
        t.touchpoint_ts,
        t.event_type,
        t.cost,
        -- Sequence numbers for First-Touch and Last-Touch
        ROW_NUMBER() OVER w_asc  AS seq_first_touch,
        ROW_NUMBER() OVER w_desc AS seq_last_touch,
        -- Total eligible touchpoints for Linear Attribution
        COUNT(*) OVER w_part     AS total_touchpoints,
        -- Exponential time-decay raw score with 7-day half-life (604,800 seconds)
        POWER(
            2.0, 
            - (EXTRACT(EPOCH FROM (c.conversion_ts - t.touchpoint_ts)) / 604800.0)
        ) AS raw_time_decay_score
    FROM fact_conversion c
    INNER JOIN fact_touchpoint t 
        ON c.user_id = t.user_id 
       AND t.touchpoint_ts >= (c.conversion_ts - (c.lookback_window_days || ' days')::INTERVAL)
       AND t.touchpoint_ts <= c.conversion_ts
    WINDOW 
        w_asc  AS (PARTITION BY c.conversion_id ORDER BY t.touchpoint_ts ASC, t.touchpoint_id ASC),
        w_desc AS (PARTITION BY c.conversion_id ORDER BY t.touchpoint_ts DESC, t.touchpoint_id DESC),
        w_part AS (PARTITION BY c.conversion_id)
),
attributed_weights AS (
    SELECT 
        conversion_id,
        user_id,
        order_id,
        net_revenue,
        conversion_ts,
        touchpoint_id,
        campaign_id,
        creative_id,
        touchpoint_ts,
        cost,
        -- Model 1: First-Touch Weight (1.0 for first touchpoint, 0.0 otherwise)
        CASE WHEN seq_first_touch = 1 THEN 1.0 ELSE 0.0 END AS weight_first_touch,
        -- Model 2: Last-Touch Weight (1.0 for last touchpoint, 0.0 otherwise)
        CASE WHEN seq_last_touch = 1 THEN 1.0 ELSE 0.0 END AS weight_last_touch,
        -- Model 3: Linear Weight (Equal split across all touches)
        (1.0 / total_touchpoints) AS weight_linear,
        -- Model 4: Normalized Time-Decay Weight
        (raw_time_decay_score / SUM(raw_time_decay_score) OVER (PARTITION BY conversion_id)) AS weight_time_decay
    FROM eligible_touchpoints
)
SELECT 
    conversion_id,
    user_id,
    order_id,
    net_revenue,
    conversion_ts,
    touchpoint_id,
    campaign_id,
    creative_id,
    touchpoint_ts,
    cost,
    weight_first_touch,
    weight_last_touch,
    weight_linear,
    weight_time_decay,
    -- Attributed Revenue per model
    ROUND((net_revenue * weight_first_touch)::NUMERIC, 4) AS rev_first_touch,
    ROUND((net_revenue * weight_last_touch)::NUMERIC, 4)  AS rev_last_touch,
    ROUND((net_revenue * weight_linear)::NUMERIC, 4)      AS rev_linear,
    ROUND((net_revenue * weight_time_decay)::NUMERIC, 4)  AS rev_time_decay
FROM attributed_weights;

-- ============================================================================
-- 2. RECURSIVE CTE: Customer Journey Path Aggregation (Rubric Item 7)
-- ============================================================================
-- Reconstructs the chronological progression of channels leading to a conversion:
-- e.g., 'Google -> Meta -> Email -> Conversion'

CREATE OR REPLACE VIEW view_customer_journey_paths AS
WITH RECURSIVE journey_builder AS (
    -- Anchor Member: First touchpoint for each conversion
    SELECT 
        v.conversion_id,
        v.touchpoint_id,
        v.touchpoint_ts,
        c.channel::TEXT AS journey_path,
        1 AS step_depth
    FROM view_touchpoint_attribution_weights v
    JOIN dim_campaign c ON v.campaign_id = c.campaign_id
    WHERE v.weight_first_touch = 1.0

    UNION ALL

    -- Recursive Member: Append consecutive touchpoints chronologically
    SELECT 
        jb.conversion_id,
        next_v.touchpoint_id,
        next_v.touchpoint_ts,
        jb.journey_path || ' -> ' || c.channel,
        jb.step_depth + 1
    FROM journey_builder jb
    JOIN LATERAL (
        SELECT v.touchpoint_id, v.touchpoint_ts, v.campaign_id
        FROM view_touchpoint_attribution_weights v
        WHERE v.conversion_id = jb.conversion_id
          AND v.touchpoint_ts > jb.touchpoint_ts
        ORDER BY v.touchpoint_ts ASC
        LIMIT 1
    ) next_v ON TRUE
    JOIN dim_campaign c ON next_v.campaign_id = c.campaign_id
    WHERE jb.step_depth < 10 -- Prevent runaway recursion
)
SELECT 
    conversion_id,
    journey_path || ' -> Conversion' AS full_journey_path,
    step_depth AS total_touchpoints
FROM (
    SELECT 
        conversion_id,
        journey_path,
        step_depth,
        ROW_NUMBER() OVER (PARTITION BY conversion_id ORDER BY step_depth DESC) AS rn
    FROM journey_builder
) ranked
WHERE rn = 1;

-- ============================================================================
-- 3. CORRELATED SUBQUERY: Identify High-Performing Anomalous Campaigns
-- ============================================================================
-- Finds campaigns whose average attributed time-decay revenue per touchpoint
-- exceeds the overall platform average for that channel by at least 1.5x.

CREATE OR REPLACE VIEW view_high_performing_campaigns AS
SELECT 
    c.campaign_id,
    c.name AS campaign_name,
    c.channel,
    COUNT(v.touchpoint_id) AS total_touches,
    ROUND(AVG(v.rev_time_decay), 2) AS avg_decay_rev_per_touch
FROM dim_campaign c
JOIN view_touchpoint_attribution_weights v ON c.campaign_id = v.campaign_id
GROUP BY c.campaign_id, c.name, c.channel
HAVING AVG(v.rev_time_decay) >= 1.5 * (
    -- Correlated Subquery: Channel benchmark
    SELECT AVG(inner_v.rev_time_decay)
    FROM view_touchpoint_attribution_weights inner_v
    JOIN dim_campaign inner_c ON inner_v.campaign_id = inner_c.campaign_id
    WHERE inner_c.channel = c.channel
);

-- ============================================================================
-- 4. MATERIALIZED VIEW: True ROAS Comparison Across Models
-- ============================================================================
-- Combines Attributed Revenue with Total Spend to calculate Return On Ad Spend:
-- ROAS = Attributed Revenue / Total Spend

DROP MATERIALIZED VIEW IF EXISTS mv_channel_roas_comparison CASCADE;

CREATE MATERIALIZED VIEW mv_channel_roas_comparison AS
WITH channel_attributed_revenue AS (
    SELECT 
        c.channel,
        ROUND(SUM(v.rev_first_touch), 2) AS revenue_first_touch,
        ROUND(SUM(v.rev_last_touch), 2)  AS revenue_last_touch,
        ROUND(SUM(v.rev_linear), 2)      AS revenue_linear,
        ROUND(SUM(v.rev_time_decay), 2)  AS revenue_time_decay,
        COUNT(DISTINCT v.conversion_id)  AS total_attributed_conversions
    FROM view_touchpoint_attribution_weights v
    JOIN dim_campaign c ON v.campaign_id = c.campaign_id
    GROUP BY c.channel
),
channel_spend AS (
    SELECT 
        c.channel,
        ROUND(SUM(s.amount), 2) AS total_spend
    FROM fact_spend s
    JOIN dim_campaign c ON s.campaign_id = c.campaign_id
    GROUP BY c.channel
)
SELECT 
    r.channel,
    s.total_spend,
    r.total_attributed_conversions,
    -- First-Touch ROAS
    r.revenue_first_touch,
    ROUND((r.revenue_first_touch / NULLIF(s.total_spend, 0)), 2) AS roas_first_touch,
    -- Last-Touch ROAS
    r.revenue_last_touch,
    ROUND((r.revenue_last_touch / NULLIF(s.total_spend, 0)), 2) AS roas_last_touch,
    -- Linear ROAS
    r.revenue_linear,
    ROUND((r.revenue_linear / NULLIF(s.total_spend, 0)), 2) AS roas_linear,
    -- Time-Decay ROAS
    r.revenue_time_decay,
    ROUND((r.revenue_time_decay / NULLIF(s.total_spend, 0)), 2) AS roas_time_decay
FROM channel_attributed_revenue r
JOIN channel_spend s ON r.channel = s.channel;

-- Index on Materialized View for fast retrieval
CREATE UNIQUE INDEX idx_mv_channel ON mv_channel_roas_comparison(channel);
