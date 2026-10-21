# Retail Analytics Engineering Platform

**Status:** Phase 2A — PostgreSQL infrastructure bootstrap only. No source ingestion, dbt transformations, or BI marts implemented yet.

## Purpose
A reproducible local PostgreSQL foundation for an omnichannel retail analytics engineering portfolio project. PostgreSQL is the persistent relational store; SQL and dbt will power analytical transformations in subsequent phases.

## Requirements
- Windows with PowerShell and Docker Desktop running (Linux containers)
- Git/GitHub Desktop and VS Code recommended
- Local TCP port 5433 available (or change `POSTGRES_PORT` in `.env`)

## Start (Windows PowerShell)
1. In the repository root, run `Copy-Item .env.example .env`.
2. Edit `.env` and replace the example password with a strong local-only password.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\start_database.ps1`.
4. Run `powershell -ExecutionPolicy Bypass -File .\scripts\verify_database.ps1`.
5. Optional: `docker compose exec postgres psql -U retail_admin -d retail_analytics` to open psql.
6. Stop without deleting data: `docker compose down`.

Expected verification: `PASS: PostgreSQL reachable; 11 operational/control tables exist.` These are 9 source tables and 2 control tables, all empty.

## Safety and lifecycle
- PostgreSQL is bound to `127.0.0.1` on the host; credentials live in untracked `.env`.
- Docker initialization scripts run **only when the named database volume is empty**. Restarting Docker does not reapply DDL.
- `docker compose down` keeps data; **do not use `down -v`** unless you explicitly intend to erase the local project database.
- This phase does not implement the future `rebuild`, `incremental`, or `validate` orchestration commands. A guarded, reproducible rebuild workflow and database migrations will be implemented in a subsequent phase.
- SQL constraints cover row-level checks and referential integrity. Cross-row financial checks, controlled error quarantine, and status-transition validation are future ingestion/dbt responsibilities.
- Before changing `POSTGRES_USER` or `POSTGRES_DB`, note that the verification script assumes the documented defaults. Changing these requires updating the script or its configuration.

## Schemas
`raw`: validated source tables; `control`: execution and rejected record metadata; `staging`, `intermediate`, `marts`: reserved for dbt models.

## Documentation
See `docs/` for the Phase 1 design baseline and data contracts. Business metrics must be computed from processed records, not hardcoded.
