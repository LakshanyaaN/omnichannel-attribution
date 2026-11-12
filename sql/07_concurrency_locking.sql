-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 07_concurrency_locking.sql
-- Description: ACID Transactions, Concurrency Control, Row-Level Locking,
--              Isolation Levels, and Savepoints (Units 3 & 4).
-- ============================================================================

-- ============================================================================
-- 1. PESSIMISTIC ROW-LEVEL LOCKING: SELECT ... FOR UPDATE
-- ============================================================================
-- Problem: Multiple ad networks simultaneously deduct ad spend from a campaign's daily budget.
-- Solution: SELECT ... FOR UPDATE acquires an exclusive row lock on the campaign,
-- blocking concurrent transactions until the current transaction commits.

BEGIN;

-- Acquire exclusive row lock on target campaign
SELECT campaign_id, daily_budget, cpc_bid
FROM dim_paid_campaign
WHERE campaign_id = (SELECT campaign_id FROM dim_paid_campaign LIMIT 1)
FOR UPDATE;

-- Simulate deduction of ad spend ($75.00)
UPDATE dim_paid_campaign
SET daily_budget = daily_budget - 75.00
WHERE campaign_id = (SELECT campaign_id FROM dim_paid_campaign LIMIT 1);

COMMIT;

-- ============================================================================
-- 2. NON-BLOCKING JOB QUEUE: SELECT ... FOR UPDATE SKIP LOCKED
-- ============================================================================
-- Problem: Multiple background workers process raw touchpoint batches concurrently.
-- Solution: SKIP LOCKED allows each worker to lock and process distinct rows
-- without waiting or causing lock contention.

BEGIN;

-- Select and lock 5 unprocessed touchpoints that are NOT already locked by another worker
SELECT touchpoint_id, user_id, campaign_id, cost
FROM fact_touchpoint
WHERE cost > 1.00
LIMIT 5
FOR UPDATE SKIP LOCKED;

-- Mark or process these specific locked touchpoints...
COMMIT;

-- ============================================================================
-- 3. PARTIAL ROLLBACKS USING SAVEPOINTS & SUBTRANSACTIONS
-- ============================================================================
-- Demonstrates nested transaction states and recovering from constraint violations
-- without aborting the parent transaction.

DO $$
DECLARE
    v_camp_id UUID;
BEGIN
    SELECT campaign_id INTO v_camp_id FROM dim_campaign LIMIT 1;

    -- Step 1: Update an active campaign
    UPDATE dim_campaign SET is_active = TRUE WHERE campaign_id = v_camp_id;

    -- Step 2: Establish a subtransaction block (Savepoint semantics in PL/pgSQL)
    BEGIN
        -- Attempt an invalid insert that violates domain check constraints
        INSERT INTO fact_spend (campaign_id, spend_date, amount)
        VALUES (v_camp_id, CURRENT_DATE, -500.00); -- INVALID: Negative spend
    EXCEPTION WHEN check_violation THEN
        -- Roll back to savepoint without aborting the parent transaction
        RAISE NOTICE 'SAVEPOINT DEMO: Caught expected check constraint violation (-500.00 spend). Partial rollback executed.';
    END;

    -- Step 3: Insert valid spend record instead
    INSERT INTO fact_spend (campaign_id, spend_date, amount)
    VALUES (v_camp_id, CURRENT_DATE, 150.00)
    ON CONFLICT (campaign_id, spend_date) 
    DO UPDATE SET amount = fact_spend.amount + EXCLUDED.amount;

    RAISE NOTICE 'SAVEPOINT DEMO: Transaction successfully committed valid data.';
END $$;

-- ============================================================================
-- 4. TRANSACTION ISOLATION LEVELS: SERIALIZABLE DETECTION
-- ============================================================================
-- Demonstrates Serializable Snapshot Isolation (SSI) which detects
-- write-skew and serialization anomalies.

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Read total attributed revenue
SELECT channel, roas_time_decay 
FROM mv_channel_roas_comparison;

-- In a serializable transaction, if a concurrent session modifies the underlying
-- facts before this commits, PostgreSQL raises:
-- ERROR: could not serialize access due to read/write dependencies among transactions.

COMMIT;
