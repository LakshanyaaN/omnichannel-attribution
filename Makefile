# Omnichannel Attribution Engine - Makefile Shortcuts
.PHONY: up down restart logs psql mongo generate load test check clean

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

psql:
	docker exec -it attribution_postgres psql -U postgres -d attribution_db

mongo:
	docker exec -it attribution_mongodb mongosh -u mongoadmin -p mongopassword --authenticationDatabase admin raw_clickstream

generate:
	python data/generator.py --scale small --scenario ai_shift

load:
	python data/load.py

test:
	@echo "Running Schema and Constraint Tests..."
	docker exec -i attribution_postgres psql -U postgres -d attribution_db < tests/01_schema_test.sql
	@echo "Running Phase 2 Advanced SQL & Programmability Tests..."
	docker exec -i attribution_postgres psql -U postgres -d attribution_db < tests/02_attribution_test.sql

clean:
	docker compose down -v
	rm -rf data/output/
