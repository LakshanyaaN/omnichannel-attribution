-- ============================================================================
-- Omnichannel Marketing Attribution Engine & Analytics Warehouse
-- Script: 02_roles_rbac.sql
-- Description: Database-level Role-Based Access Control (RBAC) implementation.
--              Enforces least privilege between Analyst and Marketing Manager.
-- ============================================================================

-- Create roles if they do not already exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_analyst') THEN
        CREATE ROLE app_analyst WITH LOGIN PASSWORD 'analyst_password_2026';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_manager') THEN
        CREATE ROLE app_manager WITH LOGIN PASSWORD 'manager_password_2026';
    END IF;
END $$;

-- 2. Schema Usage Grants
GRANT USAGE ON SCHEMA public TO app_analyst;
GRANT USAGE ON SCHEMA public TO app_manager;

-- ============================================================================
-- ROLE: app_analyst (Read-Only Analytical Access)
-- ============================================================================
-- Analysts can query dimensions, facts, and audit logs to run reports,
-- but cannot mutate campaign data, spend numbers, or raw click events.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_analyst;

-- ============================================================================
-- ROLE: app_manager (Read-Write Operational Access)
-- ============================================================================
-- Marketing managers can create campaigns, update budgets, add creatives,
-- manage spend, and insert test conversions.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_manager;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_manager;
