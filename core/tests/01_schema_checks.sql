-- 01_schema_checks.sql
-- Schema smoke test. Everything runs inside one transaction that is rolled back,
-- so the database is left untouched. Prints PASS/FAIL per check and raises an
-- error if any check fails (so `make test-core` exits non-zero).

BEGIN;

CREATE TEMP TABLE test_results (check_name TEXT, passed BOOLEAN) ON COMMIT DROP;

-- Helper: run a statement that MUST fail with a constraint error.
CREATE FUNCTION pg_temp.expect_fail(check_name TEXT, stmt TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE stmt;
    INSERT INTO test_results VALUES (check_name, FALSE);       -- it succeeded: bad
EXCEPTION WHEN integrity_constraint_violation OR check_violation THEN
    INSERT INTO test_results VALUES (check_name, TRUE);        -- it was rejected: good
END
$$ LANGUAGE plpgsql;

-- Helper: run a statement that MUST succeed.
CREATE FUNCTION pg_temp.expect_ok(check_name TEXT, stmt TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE stmt;
    INSERT INTO test_results VALUES (check_name, TRUE);
EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_results VALUES (check_name || ' (' || SQLERRM || ')', FALSE);
END
$$ LANGUAGE plpgsql;

-- ---------- sample rows ----------
INSERT INTO core.dim_user (user_id, hashed_id, signup_date)
VALUES (1, repeat('a', 64), '2026-01-01');

INSERT INTO core.campaign (campaign_id, channel, campaign_type, campaign_name, budget)
VALUES (1, 'meta',  'paid',  'Meta Awareness', 5000),
       (2, 'email', 'email', 'Welcome Series',  500);

INSERT INTO core.paid_campaign  (campaign_id, bid_strategy, daily_budget) VALUES (1, 'cpm', 100);
INSERT INTO core.email_campaign (campaign_id, list_size, send_time)       VALUES (2, 10000, '09:00');

INSERT INTO core.ad_creative (creative_id, campaign_id, creative_name, creative_type)
VALUES (1, 1, 'Video A', 'video'),
       (2, 2, 'Welcome mail', 'email_template');

-- ---------- valid inserts ----------
SELECT pg_temp.expect_ok('valid touchpoint',
  $s$INSERT INTO core.touchpoint (user_id, campaign_id, creative_id, touchpoint_ts, event_type)
     VALUES (1, 1, 1, '2026-10-01 10:00:00+00', 'impression')$s$);

SELECT pg_temp.expect_ok('valid conversion',
  $s$INSERT INTO core.conversion (conversion_id, user_id, order_id, conversion_ts, revenue)
     VALUES (1, 1, 'ORD-1', '2026-10-05 12:00:00+00', 100.00)$s$);

SELECT pg_temp.expect_ok('valid spend',
  $s$INSERT INTO core.spend (campaign_id, date_id, spend) VALUES (1, 20261001, 42.50)$s$);

-- ---------- constraints that must reject bad data ----------
SELECT pg_temp.expect_fail('duplicate touchpoint rejected',
  $s$INSERT INTO core.touchpoint (user_id, campaign_id, creative_id, touchpoint_ts, event_type)
     VALUES (1, 1, 1, '2026-10-01 10:00:00+00', 'impression')$s$);

SELECT pg_temp.expect_fail('creative from another campaign rejected',
  $s$INSERT INTO core.touchpoint (user_id, campaign_id, creative_id, touchpoint_ts, event_type)
     VALUES (1, 1, 2, '2026-10-02 10:00:00+00', 'click')$s$);

SELECT pg_temp.expect_fail('bad event_type rejected',
  $s$INSERT INTO core.touchpoint (user_id, campaign_id, creative_id, touchpoint_ts, event_type)
     VALUES (1, 1, 1, '2026-10-03 10:00:00+00', 'purchase')$s$);

SELECT pg_temp.expect_fail('touchpoint outside dim_date rejected',
  $s$INSERT INTO core.touchpoint (user_id, campaign_id, creative_id, touchpoint_ts, event_type)
     VALUES (1, 1, 1, '2035-01-01 00:00:00+00', 'click')$s$);

SELECT pg_temp.expect_fail('duplicate order_id rejected',
  $s$INSERT INTO core.conversion (user_id, order_id, conversion_ts, revenue)
     VALUES (1, 'ORD-1', '2026-10-06 12:00:00+00', 50)$s$);

SELECT pg_temp.expect_fail('zero revenue rejected',
  $s$INSERT INTO core.conversion (user_id, order_id, conversion_ts, revenue)
     VALUES (1, 'ORD-2', '2026-10-06 12:00:00+00', 0)$s$);

SELECT pg_temp.expect_fail('refunded_amount above revenue rejected',
  $s$UPDATE core.conversion SET refunded_amount = 150 WHERE conversion_id = 1$s$);

SELECT pg_temp.expect_fail('refund for missing conversion rejected',
  $s$INSERT INTO core.refund (conversion_id, refund_amount, refund_date) VALUES (999, 10, '2026-10-07')$s$);

SELECT pg_temp.expect_fail('negative spend rejected',
  $s$INSERT INTO core.spend (campaign_id, date_id, spend) VALUES (1, 20261002, -1)$s$);

SELECT pg_temp.expect_fail('duplicate spend row rejected',
  $s$INSERT INTO core.spend (campaign_id, date_id, spend) VALUES (1, 20261001, 10)$s$);

-- EER: disjoint specialization
SELECT pg_temp.expect_fail('email campaign cannot be a paid subclass',
  $s$INSERT INTO core.paid_campaign (campaign_id, bid_strategy, daily_budget) VALUES (2, 'cpc', 10)$s$);

SELECT pg_temp.expect_fail('paid campaign cannot be an email subclass',
  $s$INSERT INTO core.email_campaign (campaign_id, list_size, send_time) VALUES (1, 10, '08:00')$s$);

SELECT pg_temp.expect_fail('channel and campaign_type must agree',
  $s$INSERT INTO core.campaign (channel, campaign_type, campaign_name, budget)
     VALUES ('google', 'email', 'Bad', 10)$s$);

-- ---------- derived columns ----------
INSERT INTO test_results
SELECT 'touchpoint.date_id derived from timestamp', date_id = 20261001 FROM core.touchpoint LIMIT 1;

UPDATE core.conversion SET refunded_amount = 30 WHERE conversion_id = 1;
INSERT INTO test_results
SELECT 'net_revenue = revenue - refunded_amount', net_revenue = 70.00 FROM core.conversion WHERE conversion_id = 1;

-- ---------- api views exist ----------
INSERT INTO test_results
SELECT 'api views exist (4)',
       (SELECT count(*) FROM information_schema.views
        WHERE table_schema = 'core' AND table_name LIKE 'api\_%') = 4;

INSERT INTO test_results
SELECT 'api_touchpoints returns channel', channel = 'meta' FROM core.api_touchpoints LIMIT 1;

-- ---------- report ----------
SELECT CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS result, check_name
FROM test_results
ORDER BY passed, check_name;

DO $$
DECLARE n_fail INT;
BEGIN
    SELECT count(*) INTO n_fail FROM test_results WHERE NOT passed;
    IF n_fail > 0 THEN
        RAISE EXCEPTION '% schema check(s) failed', n_fail;
    END IF;
END
$$;

ROLLBACK;
