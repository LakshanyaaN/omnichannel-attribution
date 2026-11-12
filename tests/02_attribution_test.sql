-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 02_attribution_test.sql
-- Description: Automated verification for Stored Procedures, Triggers,
--              Attribution Window Functions, Recursive CTE, and Materialized Views.
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_camp_id UUID;
    v_creat_id UUID;
    v_conv_id UUID;
    v_status VARCHAR(50);
    v_net_rev NUMERIC(12, 2);
    v_audit_count INT;
    v_journey_path TEXT;
BEGIN
    RAISE NOTICE '=========================================================';
    RAISE NOTICE 'Starting Phase 2 Advanced SQL & Programmability Tests...';
    RAISE NOTICE '=========================================================';

    -- Setup: Create Test User, Campaign, Creative
    INSERT INTO dim_user (email, country, device_preference)
    VALUES ('phase2.test@example.com', 'USA', 'MOBILE')
    RETURNING user_id INTO v_user_id;

    INSERT INTO dim_campaign (name, channel)
    VALUES ('Phase 2 Verification Campaign', 'Meta')
    RETURNING campaign_id INTO v_camp_id;

    INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
    VALUES (v_camp_id, 2.00, 'Reels', 1000.00);

    INSERT INTO dim_creative (campaign_id, headline, body_text)
    VALUES (v_camp_id, 'High-Converting Summer Ad', 'Save up to 40% on all plans.')
    RETURNING creative_id INTO v_creat_id;

    -- Test 1: Stored Procedure sp_ingest_touchpoint (Normal insertion)
    CALL sp_ingest_touchpoint(
        v_user_id, v_camp_id, v_creat_id, 'CLICK', 2.00, CURRENT_TIMESTAMP, v_status
    );
    IF v_status <> 'SUCCESS_INSERTED' THEN
        RAISE EXCEPTION 'FAIL: sp_ingest_touchpoint failed with status: %', v_status;
    END IF;
    RAISE NOTICE 'PASS [1/6]: Stored Procedure successfully inserted new touchpoint';

    -- Test 2: Stored Procedure Idempotency (Duplicate insertion)
    CALL sp_ingest_touchpoint(
        v_user_id, v_camp_id, v_creat_id, 'CLICK', 2.00, CURRENT_TIMESTAMP, v_status
    );
    IF v_status <> 'IGNORED_DUPLICATE_IDEMPOTENT' THEN
        RAISE EXCEPTION 'FAIL: sp_ingest_touchpoint failed to detect duplicate: %', v_status;
    END IF;
    RAISE NOTICE 'PASS [2/6]: Stored Procedure idempotency check passed';

    -- Test 3: Trigger 1 (trg_deduct_refund on fact_refund)
    INSERT INTO fact_conversion (user_id, order_id, gross_revenue, net_revenue, conversion_ts)
    VALUES (v_user_id, 'ORD-P2-VERIFY', 200.00, 200.00, CURRENT_TIMESTAMP)
    RETURNING conversion_id INTO v_conv_id;

    -- Issue $50 refund
    INSERT INTO fact_refund (conversion_id, refund_amount, reason)
    VALUES (v_conv_id, 50.00, 'TEST_REFUND');

    SELECT net_revenue INTO v_net_rev FROM fact_conversion WHERE conversion_id = v_conv_id;
    IF v_net_rev <> 150.00 THEN
        RAISE EXCEPTION 'FAIL: trg_deduct_refund did not decrement net_revenue correctly. Got: %', v_net_rev;
    END IF;
    RAISE NOTICE 'PASS [3/6]: trg_deduct_refund automatically decremented net_revenue (200 -> 150)';

    -- Test 4: Trigger 2 (trg_audit_campaign_budget)
    UPDATE dim_paid_campaign
    SET daily_budget = 1200.00
    WHERE campaign_id = v_camp_id;

    SELECT COUNT(*) INTO v_audit_count 
    FROM audit_log 
    WHERE table_name = 'dim_paid_campaign' AND record_id = v_camp_id::TEXT;

    IF v_audit_count < 1 THEN
        RAISE EXCEPTION 'FAIL: trg_audit_campaign_budget failed to record audit entry';
    END IF;
    RAISE NOTICE 'PASS [4/6]: trg_audit_campaign_budget logged budget change in audit_log';

    -- Test 5: Recursive CTE Journey Path View
    SELECT full_journey_path INTO v_journey_path
    FROM view_customer_journey_paths
    WHERE conversion_id = v_conv_id;

    IF v_journey_path IS NULL THEN
        RAISE EXCEPTION 'FAIL: view_customer_journey_paths returned NULL for conversion';
    END IF;
    RAISE NOTICE 'PASS [5/6]: Recursive CTE constructed journey path: %', v_journey_path;

    -- Test 6: Materialized View Refresh
    REFRESH MATERIALIZED VIEW mv_channel_roas_comparison;
    RAISE NOTICE 'PASS [6/6]: mv_channel_roas_comparison refreshed successfully';

    RAISE NOTICE '=========================================================';
    RAISE NOTICE 'ALL PHASE 2 ADVANCED SQL & PROGRAMMABILITY CHECKS PASSED!';
    RAISE NOTICE '=========================================================';
END $$;
