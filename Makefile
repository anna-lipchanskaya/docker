.PHONY: install install-dev test run docker-run docker-stop

install:
	pip install .

install-dev:
	pip install ".[test]"

test:
	DATABASE_URL=postgresql+psycopg://kubsu:kubsu@localhost:5432/kubsu pytest tests

run:
	uvicorn src.main:app --host 0.0.0.0 --port 8112 --reload

docker-run:
	docker-compose up -d

docker-stop:
	docker-compose down

docker-logs:
	docker-compose logs -f