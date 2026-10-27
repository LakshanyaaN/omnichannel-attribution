-- 04_grants.sql
-- Privileges. Run last, after all objects exist. Safe to run more than once.

REVOKE ALL ON ALL TABLES IN SCHEMA core FROM PUBLIC;
REVOKE ALL ON SCHEMA core FROM PUBLIC;
REVOKE ALL ON SCHEMA ext  FROM PUBLIC;

-- Both roles can see inside schema core, but can only SELECT from the api_* views.
GRANT USAGE ON SCHEMA core TO ext_user, app_reader;
GRANT SELECT ON core.api_touchpoints,
                core.api_conversions,
                core.api_creatives,
                core.api_roas
    TO ext_user, app_reader;

-- Person B owns the ext schema.
GRANT USAGE, CREATE ON SCHEMA ext TO ext_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA ext GRANT ALL ON TABLES TO ext_user;

-- The web app can read what B publishes in ext (granted table by table later).
GRANT USAGE ON SCHEMA ext TO app_reader;
