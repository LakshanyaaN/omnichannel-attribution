-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 01_schema_test.sql
-- Description: Automated verification suite for tables, keys, and constraints.
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_campaign_id UUID;
    v_creative_id UUID;
    v_conversion_id UUID;
    v_error_caught BOOLEAN;
BEGIN
    RAISE NOTICE 'Starting Schema Integrity and Constraint Verification...';

    -- Test 1: Insert valid dim_user
    INSERT INTO dim_user (email, country, device_preference)
    VALUES ('test.user@example.com', 'USA', 'DESKTOP')
    RETURNING user_id INTO v_user_id;
    RAISE NOTICE 'PASS [1/7]: Insert valid user';

    -- Test 2: Verify CHECK constraint on country (must be ISO-3)
    v_error_caught := FALSE;
    BEGIN
        INSERT INTO dim_user (email, country) VALUES ('bad.country@example.com', 'US');
    EXCEPTION WHEN check_violation THEN
        v_error_caught := TRUE;
    END;
    IF NOT v_error_caught THEN
        RAISE EXCEPTION 'FAIL: Country check constraint failed to block 2-letter country code';
    END IF;
    RAISE NOTICE 'PASS [2/7]: Country ISO-3 check constraint verified';

    -- Test 3: Insert valid Campaign and Subclass
    INSERT INTO dim_campaign (name, channel, is_active)
    VALUES ('Black Friday 2026', 'Meta', TRUE)
    RETURNING campaign_id INTO v_campaign_id;

    INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
    VALUES (v_campaign_id, 1.2500, 'Instagram Stories', 500.00);
    RAISE NOTICE 'PASS [3/7]: Campaign superclass and paid specialization verified';

    -- Test 4: Insert Creative and verify generated TSVECTOR
    INSERT INTO dim_creative (campaign_id, headline, body_text)
    VALUES (v_campaign_id, 'Unbeatable Discount On Sneakers', 'Get 50 percent off today only.')
    RETURNING creative_id INTO v_creative_id;

    IF NOT EXISTS (
        SELECT 1 FROM dim_creative 
        WHERE creative_id = v_creative_id AND headline_tsv @@ to_tsquery('english', 'discount & sneakers')
    ) THEN
        RAISE EXCEPTION 'FAIL: TSVECTOR generated column did not match query terms';
    END IF;
    RAISE NOTICE 'PASS [4/7]: Creative TSVECTOR generated column and FTS search verified';

    -- Test 5: Insert valid Touchpoint and test Composite Foreign Key
    INSERT INTO fact_touchpoint (user_id, campaign_id, creative_id, event_type, cost, touchpoint_ts)
    VALUES (v_user_id, v_campaign_id, v_creative_id, 'CLICK', 1.25, CURRENT_TIMESTAMP);
    RAISE NOTICE 'PASS [5/7]: Fact touchpoint inserted with composite foreign key';

    -- Test 6: Verify Unique constraint on duplicate touchpoint timestamp
    v_error_caught := FALSE;
    BEGIN
        INSERT INTO fact_touchpoint (user_id, campaign_id, creative_id, event_type, cost, touchpoint_ts)
        SELECT user_id, campaign_id, creative_id, event_type, cost, touchpoint_ts
        FROM fact_touchpoint LIMIT 1;
    EXCEPTION WHEN unique_violation THEN
        v_error_caught := TRUE;
    END;
    IF NOT v_error_caught THEN
        RAISE EXCEPTION 'FAIL: Unique constraint on (user_id, campaign_id, touchpoint_ts) failed';
    END IF;
    RAISE NOTICE 'PASS [6/7]: Touchpoint idempotency unique constraint verified';

    -- Test 7: Verify Fact Conversion and CHECK constraint (net_revenue <= gross_revenue)
    v_error_caught := FALSE;
    BEGIN
        INSERT INTO fact_conversion (user_id, order_id, gross_revenue, net_revenue, conversion_ts)
        VALUES (v_user_id, 'ORD-9999', 100.00, 150.00, CURRENT_TIMESTAMP);
    EXCEPTION WHEN check_violation THEN
        v_error_caught := TRUE;
    END;
    IF NOT v_error_caught THEN
        RAISE EXCEPTION 'FAIL: Conversion net_revenue <= gross_revenue constraint failed';
    END IF;
    RAISE NOTICE 'PASS [7/7]: Conversion revenue check constraint verified';

    RAISE NOTICE 'ALL SCHEMA AND CONSTRAINT CHECKS PASSED SUCCESSFULLY!';
END $$;
