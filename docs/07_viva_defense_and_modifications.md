# Viva Voce Defense & Live Modification Cheat Sheet (Rubric Item 14 — 4 Marks)

This guide prepares you for the live examination and live schema/query modifications frequently requested by examiners at PES University.

---

## 1. Top 5 Live Code Modifications (With Ready-to-Run SQL)

### Modification 1: "Add a 5th Marketing Channel (e.g., 'YouTube') to the Database"
**Examiner Question:** *"Your system currently supports Google, Meta, TikTok, and Email. Can you add YouTube as an allowable channel and demonstrate that an insert succeeds?"*

**Your Action:**
In PostgreSQL, `dim_campaign.channel` is protected by a domain `CHECK` constraint. Execute this live:

```sql
-- Step 1: Drop the old CHECK constraint
ALTER TABLE dim_campaign 
DROP CONSTRAINT IF EXISTS dim_campaign_channel_check;

-- Step 2: Add updated CHECK constraint including 'YouTube'
ALTER TABLE dim_campaign 
ADD CONSTRAINT dim_campaign_channel_check 
CHECK (channel IN ('Google', 'Meta', 'TikTok', 'Email', 'YouTube'));

-- Step 3: Insert a YouTube campaign to prove it works
INSERT INTO dim_campaign (name, channel, is_active)
VALUES ('YouTube Shorts Brand Awareness 2026', 'YouTube', TRUE)
RETURNING campaign_id, name, channel;
```

---

### Modification 2: "Adjust the Time-Decay Half-Life from 7 Days to 14 Days"
**Examiner Question:** *"Show me where the mathematical decay equation is defined. Change the half-life parameter to 14 days and recompute attribution."*

**Your Action:**
Open `sql/05_programmability.sql` or run this replacement in psql:

```sql
-- Step 1: Update the user-defined function default half-life from 7.0 to 14.0 days
CREATE OR REPLACE FUNCTION fn_calculate_time_decay_weight(
    p_touchpoint_ts TIMESTAMP,
    p_conversion_ts TIMESTAMP,
    p_half_life_days NUMERIC DEFAULT 14.0 -- Modified to 14 days
)
RETURNS NUMERIC AS $$
DECLARE
    v_delta_seconds NUMERIC;
    v_half_life_seconds NUMERIC;
BEGIN
    IF p_touchpoint_ts > p_conversion_ts THEN RETURN 0.0; END IF;
    v_delta_seconds := EXTRACT(EPOCH FROM (p_conversion_ts - p_touchpoint_ts));
    v_half_life_seconds := p_half_life_days * 86400.0;
    RETURN POWER(2.0, - (v_delta_seconds / v_half_life_seconds));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Step 2: Refresh the Materialized View
REFRESH MATERIALIZED VIEW mv_channel_roas_comparison;

-- Step 3: View newly attributed ROAS
SELECT channel, roas_time_decay FROM mv_channel_roas_comparison;
```
*Explanation to Examiner:* "Doubling the half-life from 7 to 14 days flattens the decay curve, giving more credit to earlier touchpoints in the customer journey."

---

### Modification 3: "Enforce a 60-Day Expiration Policy on Refunds"
**Examiner Question:** *"Modify your refund trigger (`trg_deduct_refund`) so that refunds requested more than 60 days after the conversion date are rejected."*

**Your Action:**
Update the trigger function with an age check:

```sql
CREATE OR REPLACE FUNCTION fn_process_refund_deduction()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_ts TIMESTAMP;
    v_current_net NUMERIC(12, 2);
BEGIN
    SELECT conversion_ts, net_revenue INTO v_conv_ts, v_current_net
    FROM fact_conversion
    WHERE conversion_id = NEW.conversion_id
    FOR UPDATE;

    -- Live Modification: 60-day policy
    IF (NEW.refund_ts - v_conv_ts) > INTERVAL '60 days' THEN
        RAISE EXCEPTION 'REJECTED: Refund requested after the 60-day return policy window.';
    END IF;

    UPDATE fact_conversion
    SET net_revenue = GREATEST(0.00, net_revenue - NEW.refund_amount)
    WHERE conversion_id = NEW.conversion_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### Modification 4: "Write a Live Correlated Subquery to Find Anomalous High-Touch Customers"
**Examiner Question:** *"Can you write a query on the spot that finds users who had more touchpoints than the average user in their country?"*

**Your Action:**
Type and run this correlated subquery:

```sql
SELECT 
    u.user_id,
    u.email,
    u.country,
    COUNT(t.touchpoint_id) AS user_touch_count
FROM dim_user u
JOIN fact_touchpoint t ON u.user_id = t.user_id
GROUP BY u.user_id, u.email, u.country
HAVING COUNT(t.touchpoint_id) > (
    -- Correlated Subquery: Country average
    SELECT AVG(inner_count)
    FROM (
        SELECT COUNT(inner_t.touchpoint_id) AS inner_count
        FROM dim_user inner_u
        JOIN fact_touchpoint inner_t ON inner_u.user_id = inner_t.user_id
        WHERE inner_u.country = u.country -- Correlation variable
        GROUP BY inner_u.user_id
    ) sub
)
LIMIT 5;
```

---

### Modification 5: "Prove Database-Enforced RBAC Without Using the Frontend"
**Examiner Question:** *"You claim your RBAC is enforced in the database and not just in Next.js. Prove it to me using pure SQL."*

**Your Action:**
Run two consecutive psql commands using the different database credentials:

```bash
# 1. Test as app_analyst (Must fail on write):
docker exec -i attribution_postgres psql -U app_analyst -d attribution_db -c \
  "INSERT INTO dim_campaign (name, channel) VALUES ('Hacked Campaign', 'Google');"

# Output: ERROR: permission denied for table dim_campaign (SQLSTATE 42501)

# 2. Test as app_manager (Must succeed on write):
docker exec -i attribution_postgres psql -U app_manager -d attribution_db -c \
  "INSERT INTO dim_campaign (name, channel) VALUES ('Manager Approved Campaign', 'Google');"

# Output: INSERT 0 1
```

---

## 2. Theoretical Viva Questions & Master Answers

### Q1: "Why did you use BCNF for operational tables but denormalize the Date Dimension in the Star Schema?"
* **Answer:** "Operational master tables (Users, Campaigns) strictly adhere to **BCNF** to prevent update, insertion, and deletion anomalies. However, analytical warehousing prioritizes query execution speed. Analytical attribution queries aggregate metrics by month, quarter, and year across millions of click events. If `dim_date` were fully normalized, the query planner would be forced to execute 3 extra relational joins per query. Denormalizing `dim_date` enables constant-time $O(1)$ attribute lookups without risk of anomalies because calendar dates are completely immutable."

### Q2: "Why use MongoDB for raw clickstreams instead of landing everything directly into PostgreSQL?"
* **Answer:** "Digital advertising platforms (Google Ads, Meta Graph API, TikTok Events API) deliver clickstream payloads in heterogeneous JSON structures with unexpected nested UTM tags and telemetry parameters. If we ingested directly into a rigid relational schema, any schema drift or malformed parameter would cause the entire ingestion transaction to abort. MongoDB acts as our ELT landing buffer, accepting variable-schema JSON at high velocity. We then cleanse and validate records before loading them into the PostgreSQL Star Schema."

### Q3: "How does HNSW (Hierarchical Navigable Small World) index work in pgvector vs traditional B-Trees?"
* **Answer:** "Traditional B-Tree indexes only work on 1-dimensional ordered scalar values (e.g., numbers, dates, alphabetical strings) where $A < B < C$. Dense vector embeddings reside in a 384-dimensional continuous metric space where scalars cannot be linearly sorted. HNSW builds a multi-layered graph where top layers have long-range skip edges and bottom layers have dense local clustering. Search traverses the sparse top layers in $O(\log N)$ time to locate the nearest neighborhood, and then descends into the dense lower layers to locate the exact nearest semantic neighbors."

### Q4: "What is the Lost Update Anomaly, and how does your project eliminate it?"
* **Answer:** "The Lost Update anomaly occurs when two concurrent transactions read the same record simultaneously (e.g. Daily Budget = $500), both deduct a spend amount (e.g. $150), and both write back their result ($350). The second transaction overwrites the first, causing $150 of advertising spend to disappear from accounting. We solve this using **Pessimistic Row-Level Locking (`SELECT ... FOR UPDATE`)**, which acquires an exclusive row-level lock on `dim_paid_campaign`. The second transaction is placed in a sleep wait until the first transaction commits, guaranteeing serial execution and 100% balance consistency."

### Q5: "How does the Recursive CTE prevent infinite loops when traversing customer journeys?"
* **Answer:** "Customer journeys could theoretically loop if a user repeatedly clicks the same channel. In `view_customer_journey_paths`, we enforce two termination conditions:
1. `WHERE next_t.touchpoint_ts > jb.touchpoint_ts` enforces strict temporal monotonicity (time can only move forward).
2. `WHERE jb.step_depth < 10` serves as a recursion ceiling, stopping recursion after 10 touchpoints to prevent stack overflow."
