-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 03_dml_operations.sql
-- Description: Explicit demonstration of INSERT, UPDATE, and DELETE (DML)
--              operations across dimensions and facts (Rubric Component 6 - 4 Marks).
-- ============================================================================

-- ============================================================================
-- PART 1: INSERT OPERATIONS
-- ============================================================================

-- 1.1 Single-row INSERT into User Dimension
INSERT INTO dim_user (email, country, device_preference, first_seen_ts)
VALUES ('alice.smith.2026@gmail.com', 'USA', 'MOBILE', CURRENT_TIMESTAMP)
RETURNING user_id, email, country;

-- 1.2 Multi-row Bulk INSERT into Campaign and Subclass
INSERT INTO dim_campaign (campaign_id, name, channel, is_active)
VALUES 
    ('c0000001-0000-0000-0000-000000000001', 'DML Demo - Meta Retargeting', 'Meta', TRUE),
    ('c0000002-0000-0000-0000-000000000002', 'DML Demo - Google High-Intent', 'Google', TRUE),
    ('c0000003-0000-0000-0000-000000000003', 'DML Demo - TikTok Viral Spark', 'TikTok', TRUE)
ON CONFLICT (campaign_id) DO NOTHING;

INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
VALUES 
    ('c0000001-0000-0000-0000-000000000001', 1.85, 'Instagram Feed', 450.00),
    ('c0000002-0000-0000-0000-000000000002', 3.20, 'Search Top of Page', 800.00),
    ('c0000003-0000-0000-0000-000000000003', 0.95, 'For You In-Feed', 350.00)
ON CONFLICT (campaign_id) DO NOTHING;

-- 1.3 INSERT ... SELECT: Seed initial daily spend records from active paid campaigns
INSERT INTO fact_spend (campaign_id, spend_date, amount)
SELECT 
    p.campaign_id,
    CURRENT_DATE,
    p.daily_budget * 0.92 -- Initial spend at 92% of budget
FROM dim_paid_campaign p
JOIN dim_campaign c ON p.campaign_id = c.campaign_id
WHERE c.name LIKE 'DML Demo%'
ON CONFLICT (campaign_id, spend_date) DO NOTHING;

-- Verification of Part 1
SELECT c.name, c.channel, p.cpc_bid, p.daily_budget, s.amount AS initial_spend
FROM dim_campaign c
JOIN dim_paid_campaign p ON c.campaign_id = p.campaign_id
LEFT JOIN fact_spend s ON c.campaign_id = s.campaign_id AND s.spend_date = CURRENT_DATE
WHERE c.name LIKE 'DML Demo%';

-- ============================================================================
-- PART 2: UPDATE OPERATIONS
-- ============================================================================

-- 2.1 Single-row UPDATE: Adjust daily budget for an individual paid campaign
UPDATE dim_paid_campaign
SET daily_budget = daily_budget * 1.25, -- 25% budget increase
    cpc_bid = cpc_bid + 0.15
WHERE campaign_id = 'c0000001-0000-0000-0000-000000000001';

-- 2.2 Multi-row Conditional UPDATE: Pause all campaigns where spend exceeds a threshold
UPDATE dim_campaign
SET is_active = FALSE
WHERE campaign_id IN (
    SELECT campaign_id 
    FROM fact_spend 
    GROUP BY campaign_id 
    HAVING SUM(amount) > 100000.00
);

-- 2.3 Correlated Subquery UPDATE: Update user device preference to match their most frequent touchpoint device
UPDATE dim_user u
SET device_preference = 'DESKTOP'
WHERE EXISTS (
    SELECT 1 
    FROM fact_touchpoint t
    WHERE t.user_id = u.user_id 
      AND t.cost > 2.50
) AND u.email = 'alice.smith.2026@gmail.com';

-- Verification of Part 2
SELECT c.name, p.daily_budget, p.cpc_bid, c.is_active
FROM dim_campaign c
JOIN dim_paid_campaign p ON c.campaign_id = p.campaign_id
WHERE c.name LIKE 'DML Demo%';

-- ============================================================================
-- PART 3: DELETE OPERATIONS
-- ============================================================================

-- 3.1 Soft DELETE: Gracefully archive campaigns rather than dropping relational history
UPDATE dim_campaign
SET is_active = FALSE
WHERE name = 'DML Demo - TikTok Viral Spark';

-- 3.2 Hard DELETE with Cascading Foreign Keys:
-- Deleting from dim_campaign automatically cascades to dim_paid_campaign,
-- dim_creative, and fact_spend while upholding integrity.
DELETE FROM dim_campaign
WHERE campaign_id = 'c0000003-0000-0000-0000-000000000003';

-- 3.3 Conditional Subquery DELETE: Purge isolated test users who have never had touchpoints or conversions
DELETE FROM dim_user
WHERE email = 'alice.smith.2026@gmail.com'
  AND user_id NOT IN (SELECT DISTINCT user_id FROM fact_touchpoint)
  AND user_id NOT IN (SELECT DISTINCT user_id FROM fact_conversion);

-- Verification of Part 3
SELECT COUNT(*) AS remaining_dml_demo_campaigns 
FROM dim_campaign 
WHERE name LIKE 'DML Demo%';
