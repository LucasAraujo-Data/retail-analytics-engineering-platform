# Phase 2D — Reproducible Docker pipeline

This package adds a Docker-based Python + dbt pipeline to the existing PostgreSQL Compose stack.

## Installation

Copy `docker-compose.yml`, `Dockerfile.pipeline`, and `scripts/container_pipeline.py` into the corresponding paths in the repository. **Back up your current `docker-compose.yml` first.**

Update `scripts/load_retail_data.py`: in the `connection()` function, replace `host='127.0.0.1'` with `host=os.getenv('POSTGRES_HOST', '127.0.0.1')`. Keep the rest of the function unchanged. This enables the same loader to run both on Windows and inside Docker.

Keep `.env` private. Never commit it. The `.env.example` is safe to publish if it contains placeholder credentials only.

## Running

With Docker Desktop running, from the repository root:

```powershell
docker compose --profile pipeline up --build --abort-on-container-exit --exit-code-from pipeline
```

A first run on an empty database loads synthetic data, runs dbt models and tests. Later runs validate existing raw data and rebuild the dbt models; they **do not reset the raw data**. Use `docker compose up -d postgres` for database-only startup.

The database is published on localhost port 5433 by default. Container-to-container traffic uses `postgres:5432`.

## Notes

- `docker compose up --build` alone starts only PostgreSQL. The explicit `--profile pipeline` enables the pipeline service and prevents unintended pipeline runs during normal database startup.
- The pipeline exits when complete; PostgreSQL can remain running.
- Never use `docker compose down -v` unless you intentionally want to delete the database volume.
- This package does not implement schema migrations or full incremental dbt materializations.
- Run `git status` and inspect changes before committing. Do not commit `.env` or database volumes.
