# Minimal Makefile for A1. More targets (load, test-core for all checks, up-ext, web) come with A8.
-include .env
POSTGRES_USER ?= postgres
POSTGRES_DB   ?= attribution
CORE = docker compose -f compose.core.yml
PSQL = $(CORE) exec -T db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -v ON_ERROR_STOP=1

.PHONY: up down reset psql test-core

up:            ## start PostgreSQL; the schema loads automatically on first start
	$(CORE) up -d --build

down:          ## stop containers, keep data
	$(CORE) down

reset:         ## wipe the database volume and rebuild from core/sql
	$(CORE) down -v
	$(CORE) up -d --build

psql:          ## open a SQL shell
	$(CORE) exec db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

test-core:     ## run the schema checks
	$(PSQL) < core/tests/01_schema_checks.sql
