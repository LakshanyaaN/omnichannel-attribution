-- 03_api_views.sql
-- The read-only contract between Person A (core) and Person B (ext, web app).
-- Column names and types below are frozen as v1 at the end of Week 2.
-- Person B never reads core tables directly, only these views.

CREATE OR REPLACE VIEW core.api_touchpoints AS
SELECT t.touchpoint_id,
       t.user_id,
       t.campaign_id,
       c.channel,
       t.creative_id,
       t.event_type,
       t.touchpoint_ts,
       t.date_id
FROM core.touchpoint t
JOIN core.campaign   c ON c.campaign_id = t.campaign_id;

CREATE OR REPLACE VIEW core.api_conversions AS
SELECT conversion_id,
       user_id,
       order_id,
       conversion_ts,
       revenue,
       refunded_amount,
       net_revenue,
       currency,
       date_id
FROM core.conversion;

CREATE OR REPLACE VIEW core.api_creatives AS
SELECT a.creative_id,
       a.campaign_id,
       c.channel,
       c.campaign_name,
       a.creative_name,
       a.creative_type,
       a.description
FROM core.ad_creative a
JOIN core.campaign    c ON c.campaign_id = a.campaign_id;

-- api_roas: column layout is fixed now; A4 replaces the body with the real
-- ROAS query over the materialized views (CREATE OR REPLACE keeps the same columns).
CREATE OR REPLACE VIEW core.api_roas AS
SELECT NULL::TEXT          AS channel,
       NULL::TEXT          AS attribution_model,   -- first_touch | last_touch | linear | time_decay
       NULL::NUMERIC(14,2) AS spend,
       NULL::NUMERIC(14,2) AS attributed_revenue,
       NULL::NUMERIC(10,4) AS roas
WHERE FALSE;
