-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 01_schema_ddl.sql
-- Description: DDL for PostgreSQL 16 with pgvector, full-text search, domain
--              constraints, EER specialization, and analytical star schema.
-- ============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- 2. Drop existing tables if re-initializing (Order respecting foreign keys)
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS fact_refund CASCADE;
DROP TABLE IF EXISTS fact_conversion CASCADE;
DROP TABLE IF EXISTS fact_touchpoint CASCADE;
DROP TABLE IF EXISTS fact_spend CASCADE;
DROP TABLE IF EXISTS dim_creative CASCADE;
DROP TABLE IF EXISTS dim_email_campaign CASCADE;
DROP TABLE IF EXISTS dim_paid_campaign CASCADE;
DROP TABLE IF EXISTS dim_campaign CASCADE;
DROP TABLE IF EXISTS dim_user CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- ============================================================================
-- DIMENSIONS (Operational & Categorical)
-- ============================================================================

-- Dimension: User Profiles
CREATE TABLE dim_user (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    country VARCHAR(3) NOT NULL CHECK (char_length(country) = 3), -- ISO alpha-3
    device_preference VARCHAR(20) DEFAULT 'MOBILE' CHECK (device_preference IN ('MOBILE', 'DESKTOP', 'TABLET')),
    first_seen_ts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Dimension: Campaign Superclass
CREATE TABLE dim_campaign (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    channel VARCHAR(30) NOT NULL CHECK (channel IN ('Google', 'Meta', 'TikTok', 'Email')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_campaign_name UNIQUE (name)
);

-- Subclass (EER Specialization): Paid Ad Campaigns
CREATE TABLE dim_paid_campaign (
    campaign_id UUID PRIMARY KEY REFERENCES dim_campaign(campaign_id) ON DELETE CASCADE,
    cpc_bid NUMERIC(8, 4) NOT NULL CHECK (cpc_bid >= 0),
    target_network VARCHAR(50) NOT NULL,
    daily_budget NUMERIC(10, 2) NOT NULL CHECK (daily_budget >= 0)
);

-- Subclass (EER Specialization): Email Campaigns
CREATE TABLE dim_email_campaign (
    campaign_id UUID PRIMARY KEY REFERENCES dim_campaign(campaign_id) ON DELETE CASCADE,
    sender_domain VARCHAR(100) NOT NULL,
    template_id VARCHAR(50) NOT NULL,
    audience_segment VARCHAR(50) NOT NULL DEFAULT 'ALL'
);

-- Dimension: Ad Creative (Includes TSVector Full-Text Search and Vector Embeddings)
CREATE TABLE dim_creative (
    creative_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES dim_campaign(campaign_id) ON DELETE CASCADE,
    headline VARCHAR(255) NOT NULL,
    body_text TEXT,
    call_to_action VARCHAR(50) NOT NULL DEFAULT 'Learn More',
    -- Generated Column for PostgreSQL Full-Text Search
    headline_tsv TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', headline || ' ' || COALESCE(body_text, ''))
    ) STORED,
    -- 384-dimensional dense vector embedding (e.g. all-MiniLM-L6-v2)
    embedding vector(384),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Unique compound key for composite foreign key constraint
    CONSTRAINT uq_creative_campaign UNIQUE (creative_id, campaign_id)
);

-- Dimension: Analytical Date Dimension (Consciously denormalized for OLAP performance)
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,                       -- YYYYMMDD
    full_date DATE UNIQUE NOT NULL,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_name VARCHAR(10) NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    month_number INT NOT NULL CHECK (month_number BETWEEN 1 AND 12),
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    year INT NOT NULL CHECK (year >= 2020),
    is_weekend BOOLEAN NOT NULL
);

-- ============================================================================
-- FACTS (Measurable Events & Conversions)
-- ============================================================================

-- Fact: Touchpoint Events (Impressions and Clicks)
CREATE TABLE fact_touchpoint (
    touchpoint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES dim_user(user_id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL,
    creative_id UUID NOT NULL,
    event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('IMPRESSION', 'CLICK')),
    cost NUMERIC(10, 4) NOT NULL CHECK (cost >= 0),
    touchpoint_ts TIMESTAMPTZ NOT NULL,
    -- Generated date column for fast date partitioning / joining
    touchpoint_date DATE GENERATED ALWAYS AS (touchpoint_ts::DATE) STORED,
    -- Compound foreign key ensures creative belongs to declared campaign
    CONSTRAINT fk_touchpoint_creative_campaign 
        FOREIGN KEY (creative_id, campaign_id) 
        REFERENCES dim_creative(creative_id, campaign_id) ON DELETE RESTRICT,
    -- Enforce idempotency: prevent duplicate events per user/campaign/millisecond
    CONSTRAINT uq_user_event_time UNIQUE (user_id, campaign_id, touchpoint_ts)
);

-- Fact: Conversions (Orders & Revenue)
CREATE TABLE fact_conversion (
    conversion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES dim_user(user_id) ON DELETE CASCADE,
    order_id VARCHAR(100) UNIQUE NOT NULL,
    gross_revenue NUMERIC(12, 2) NOT NULL CHECK (gross_revenue > 0),
    net_revenue NUMERIC(12, 2) NOT NULL CHECK (net_revenue >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    conversion_ts TIMESTAMPTZ NOT NULL,
    conversion_date DATE GENERATED ALWAYS AS (conversion_ts::DATE) STORED,
    lookback_window_days INT NOT NULL DEFAULT 30 CHECK (lookback_window_days > 0),
    CONSTRAINT chk_net_lte_gross CHECK (net_revenue <= gross_revenue)
);

-- Fact: Refunds (Decrements Net Conversion Value)
CREATE TABLE fact_refund (
    refund_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversion_id UUID NOT NULL REFERENCES fact_conversion(conversion_id) ON DELETE RESTRICT,
    refund_amount NUMERIC(12, 2) NOT NULL CHECK (refund_amount > 0),
    refund_ts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(100) DEFAULT 'CUSTOMER_RETURN'
);

-- Fact: Daily Marketing Spend (Used to compute ROAS per campaign/platform)
CREATE TABLE fact_spend (
    spend_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES dim_campaign(campaign_id) ON DELETE CASCADE,
    spend_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    CONSTRAINT uq_campaign_spend_date UNIQUE (campaign_id, spend_date)
);

-- ============================================================================
-- AUDIT & COMPLIANCE
-- ============================================================================

CREATE TABLE audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id VARCHAR(100) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    performed_by VARCHAR(50) NOT NULL DEFAULT CURRENT_USER,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- PERFORMANCE & SEARCH INDEXES
-- ============================================================================

-- B-Tree indexes for fast join and lookback window range filtering
CREATE INDEX idx_touchpoint_user_ts ON fact_touchpoint(user_id, touchpoint_ts);
CREATE INDEX idx_touchpoint_campaign ON fact_touchpoint(campaign_id);
CREATE INDEX idx_touchpoint_date ON fact_touchpoint(touchpoint_date);
CREATE INDEX idx_conversion_user_ts ON fact_conversion(user_id, conversion_ts);
CREATE INDEX idx_conversion_order ON fact_conversion(order_id);
CREATE INDEX idx_spend_campaign_date ON fact_spend(campaign_id, spend_date);

-- GIN Index for Full-Text Search
CREATE INDEX idx_creative_fts ON dim_creative USING GIN (headline_tsv);

-- HNSW Index for pgvector Cosine Distance Search
CREATE INDEX idx_creative_embedding ON dim_creative USING hnsw (embedding vector_cosine_ops);
