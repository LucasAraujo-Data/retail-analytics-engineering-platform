# Phase 2B — Synthetic Retail Data Loading

This package adds Python ingestion to the existing Docker/PostgreSQL project. It does not overwrite the schema or Docker configuration.

## Install

Copy the `scripts/` files and `requirements.txt` into the project root. From PowerShell in the repository root:

```powershell
python --version
python -m pip install -r requirements.txt
.\scripts\run_data_pipeline.ps1 -Mode rebuild -Orders 15000 -Seed 42
```

The existing `.env` must define `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_PORT` (5433 by default). PostgreSQL must be running (`.\scripts\start_database.ps1`). Never commit `.env`.

## Modes

```powershell
.\scripts\run_data_pipeline.ps1 -Mode validate
.\scripts\run_data_pipeline.ps1 -Mode incremental -Orders 2000 -Seed 43
.\scripts\run_data_pipeline.ps1 -Mode rebuild -Orders 15000 -Seed 42
```

- `rebuild`: truncates operational `raw` tables and regenerates synthetic records; audit history remains.
- `incremental`: appends new orders, customers, payments and returns; dimension catalog remains unchanged.
- `validate`: runs checks without modifying operational data.

All generated data are synthetic. The generator uses a seeded pseudo-random stream; timestamps are anchored to execution time, so reruns on different dates are not byte-for-byte identical. `rebuild` is destructive to existing `raw` data. No actual source-system CDC or late-arriving record reconciliation is implemented at this stage.

The generator creates coherent orders, items, payments and returns with foreign keys, discount reconciliation and date constraints. It intentionally does **not** claim realistic seasonal demand, inventory, tax, freight, or refunds modeling yet. Completed returns are recorded independently of payment status.

## Architecture

Python runs on the host and connects to PostgreSQL inside Docker via `127.0.0.1:5433`. Data are stored in PostgreSQL's Docker volume. This phase does not include dbt or containerized Python; those are subsequent stages.

## Known limits

- Single-process loader; do not run two ingestion jobs concurrently.
- No row-level quarantine is implemented: a database constraint error fails and rolls back the entire batch. The `control.rejected_records` table is reserved for a later enhancement.
- `control.pipeline_runs` records successful/failed executions, but a failure before the first connection cannot be audited.
- The Python requirements use compatible version ranges; a lockfile will be added when the environment is stabilized.
