-- 00_setup.sql
-- Schemas and roles. Safe to run more than once.
--
--   core  : Person A's warehouse (tables, procedures, triggers, api_* views)
--   ext   : Person B's extension tables (full-text search, vectors, ...)
--
-- Roles
--   ext_user   : Person B. Can read api_* views and has full control of schema ext.
--   app_reader : the Next.js app. Can only read api_* views.
-- Change the passwords below (or set them from your .env) before sharing the database.

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ext;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ext_user') THEN
        CREATE ROLE ext_user LOGIN PASSWORD 'change_me_ext_user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_reader') THEN
        CREATE ROLE app_reader LOGIN PASSWORD 'change_me_app_reader';
    END IF;
END
$$;
