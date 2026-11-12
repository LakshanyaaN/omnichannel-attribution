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
	@echo "Running Phase 3 NoSQL & Vector RUD Tests..."
	python tests/03_nosql_vector_rud_test.py
	@echo "Running Phase 4 Concurrency & Row-Locking Tests..."
	python tests/04_concurrency_test.py

concurrency:
	docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/07_concurrency_locking.sql
	python tests/04_concurrency_test.py

explain:
	docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/08_query_optimization_demo.sql

vector:
	docker exec -i attribution_postgres psql -U postgres -d attribution_db < sql/06_vector_search.sql

analytics:
	python data/mongo_analytics.py

clean:
	docker compose down -v
	rm -rf data/output/
