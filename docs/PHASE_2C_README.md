# Phase 2C — dbt analytics layer

## Installation (Windows PowerShell)

Copy `dbt/` into the repository root, and `run_dbt.ps1` into the repository's `scripts/` folder. Keep `requirements-dbt.txt` at the repository root.

Run from the repository root:

```powershell
python -m pip install -r .\requirements-dbt.txt
.\scripts\run_dbt.ps1 -Mode debug
.\scripts\run_dbt.ps1 -Mode build
.\scripts\run_dbt.ps1 -Mode docs
```

The PowerShell script reads local `.env` without printing its secrets. Keep `.env` ignored by Git. This phase expects the PostgreSQL container and raw data pipeline to have been started.

## dbt schemas

The project uses dbt custom schemas `staging`, `intermediate`, and `marts`. dbt-postgres default schema naming concatenates the target schema with custom schema (e.g. `public_marts`), so this project includes a custom `generate_schema_name` macro to place models in the pre-existing schemas.

## Business definitions

Only `CONFIRMED` or `FULFILLED` orders with at least one `APPROVED` payment are treated as sales. Item amounts are computed at the item grain. Completed returns are recorded by completion date. `mart_sales_daily` reports revenue and returns by their own event dates, so daily net sales can include returns from earlier sales. COGS in that mart is pre-returns and should not be used as post-return gross margin.

## Next phase

Add the Docker-based Python/dbt runner, incremental models, richer return-adjusted margin logic, and BI publishing after validating this baseline.
