-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 05_programmability.sql
-- Description: Stored Procedures, Functions, and Triggers (Rubric Component 8 - 6 Marks).
-- ============================================================================

-- ============================================================================
-- 1. USER-DEFINED FUNCTION: Exponential Decay Weight Calculation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_time_decay_weight(
    p_touchpoint_ts TIMESTAMP,
    p_conversion_ts TIMESTAMP,
    p_half_life_days NUMERIC DEFAULT 7.0
)
RETURNS NUMERIC AS $$
DECLARE
    v_delta_seconds NUMERIC;
    v_half_life_seconds NUMERIC;
BEGIN
    IF p_touchpoint_ts > p_conversion_ts THEN
        RETURN 0.0;
    END IF;

    v_delta_seconds := EXTRACT(EPOCH FROM (p_conversion_ts - p_touchpoint_ts));
    v_half_life_seconds := p_half_life_days * 86400.0;

    -- Formula: 2^(-delta_t / half_life)
    RETURN POWER(2.0, - (v_delta_seconds / v_half_life_seconds));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- 2. TRIGGER 1: Automated Net Revenue Adjustment on Refund (Data Consistency)
-- ============================================================================
-- Automatically subtracts the refund amount from the conversion's net revenue.
-- Enforces that net revenue cannot drop below zero.

CREATE OR REPLACE FUNCTION fn_process_refund_deduction()
RETURNS TRIGGER AS $$
DECLARE
    v_current_net NUMERIC(12, 2);
BEGIN
    SELECT net_revenue INTO v_current_net
    FROM fact_conversion
    WHERE conversion_id = NEW.conversion_id
    FOR UPDATE; -- Pessimistic lock on conversion record

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Referenced Conversion ID % does not exist.', NEW.conversion_id;
    END IF;

    IF NEW.refund_amount > v_current_net THEN
        RAISE NOTICE 'Refund amount (%) exceeds remaining net revenue (%). Clamping to 0.00.', 
                     NEW.refund_amount, v_current_net;
    END IF;

    UPDATE fact_conversion
    SET net_revenue = GREATEST(0.00, net_revenue - NEW.refund_amount)
    WHERE conversion_id = NEW.conversion_id;

    -- Insert into audit log
    INSERT INTO audit_log (table_name, operation, record_id, old_data, new_data, performed_by)
    VALUES (
        'fact_conversion',
        'UPDATE',
        NEW.conversion_id::TEXT,
        jsonb_build_object('previous_net_revenue', v_current_net),
        jsonb_build_object('refund_id', NEW.refund_id, 'refund_amount', NEW.refund_amount, 'new_net_revenue', GREATEST(0.00, v_current_net - NEW.refund_amount)),
        CURRENT_USER
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_deduct_refund ON fact_refund;
CREATE TRIGGER trg_deduct_refund
AFTER INSERT ON fact_refund
FOR EACH ROW
EXECUTE FUNCTION fn_process_refund_deduction();

-- ============================================================================
-- 3. TRIGGER 2: Campaign Daily Budget Change Audit Trail
-- ============================================================================
-- Every time a campaign's daily budget or bid is adjusted, logs before/after diffs.

CREATE OR REPLACE FUNCTION fn_audit_campaign_budget_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.daily_budget <> NEW.daily_budget) OR (OLD.cpc_bid <> NEW.cpc_bid) THEN
        INSERT INTO audit_log (table_name, operation, record_id, old_data, new_data, performed_by)
        VALUES (
            'dim_paid_campaign',
            'UPDATE',
            NEW.campaign_id::TEXT,
            jsonb_build_object('cpc_bid', OLD.cpc_bid, 'daily_budget', OLD.daily_budget),
            jsonb_build_object('cpc_bid', NEW.cpc_bid, 'daily_budget', NEW.daily_budget),
            CURRENT_USER
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_campaign_budget ON dim_paid_campaign;
CREATE TRIGGER trg_audit_campaign_budget
AFTER UPDATE ON dim_paid_campaign
FOR EACH ROW
EXECUTE FUNCTION fn_audit_campaign_budget_change();

-- ============================================================================
-- 4. STORED PROCEDURE: Ingestion Pipeline with Transaction Control
-- ============================================================================
-- Ingests raw touchpoints with validation, exception handling, and idempotency.

CREATE OR REPLACE PROCEDURE sp_ingest_touchpoint(
    p_user_id UUID,
    p_campaign_id UUID,
    p_creative_id UUID,
    p_event_type VARCHAR(20),
    p_cost NUMERIC(10, 4),
    p_touchpoint_ts TIMESTAMP,
    INOUT p_status VARCHAR(50) DEFAULT 'INITIALIZING'
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Validation 1: Event type
    IF p_event_type NOT IN ('IMPRESSION', 'CLICK') THEN
        p_status := 'REJECTED_INVALID_EVENT_TYPE';
        RETURN;
    END IF;

    -- Validation 2: Cost cannot be negative
    IF p_cost < 0 THEN
        p_status := 'REJECTED_NEGATIVE_COST';
        RETURN;
    END IF;

    -- Insert into fact table; gracefully handle duplicate events
    INSERT INTO fact_touchpoint (
        user_id,
        campaign_id,
        creative_id,
        event_type,
        cost,
        touchpoint_ts
    )
    VALUES (
        p_user_id,
        p_campaign_id,
        p_creative_id,
        p_event_type,
        p_cost,
        p_touchpoint_ts
    )
    ON CONFLICT (user_id, campaign_id, touchpoint_ts) DO NOTHING;

    IF FOUND THEN
        p_status := 'SUCCESS_INSERTED';
    ELSE
        p_status := 'IGNORED_DUPLICATE_IDEMPOTENT';
    END IF;

EXCEPTION WHEN OTHERS THEN
    p_status := 'ERROR: ' || SQLERRM;
END;
$$;
