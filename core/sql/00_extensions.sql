-- 00_extensions.sql
-- Extensions that ship with the project's Postgres image (core/docker/Dockerfile.postgres).
-- pg_cron is enabled later in A4, when the refresh jobs are written.
CREATE EXTENSION IF NOT EXISTS vector;
