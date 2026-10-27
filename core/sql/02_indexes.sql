-- 02_indexes.sql
-- Secondary indexes. PostgreSQL does not index foreign-key columns automatically.
--
-- Already covered without a separate index:
--   * touchpoint (user_id, touchpoint_ts, ...) : the UNIQUE constraint uq_touchpoint_event
--     serves the lookback join (same user, earlier timestamps).
--   * conversion.order_id, dim_user.hashed_id, dim_date.full_date : UNIQUE constraints.
--
-- A7 will drop and recreate these to produce the before/after EXPLAIN ANALYZE timings.

CREATE INDEX idx_touchpoint_campaign_date ON core.touchpoint (campaign_id, date_id);
CREATE INDEX idx_touchpoint_creative      ON core.touchpoint (creative_id);
CREATE INDEX idx_touchpoint_date          ON core.touchpoint (date_id);

CREATE INDEX idx_conversion_user_ts       ON core.conversion (user_id, conversion_ts);
CREATE INDEX idx_conversion_date          ON core.conversion (date_id);

CREATE INDEX idx_refund_conversion        ON core.refund (conversion_id);

CREATE INDEX idx_ad_creative_campaign     ON core.ad_creative (campaign_id);
CREATE INDEX idx_campaign_channel         ON core.campaign (channel);
CREATE INDEX idx_spend_date               ON core.spend (date_id);
