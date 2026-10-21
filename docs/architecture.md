# Retail Analytics Engineering Platform — Architecture

**Status:** Phase 1 design baseline (proposed; not implemented)  
**Decision:** ADR-002 — PostgreSQL is the primary persistent store; SQL and dbt are the central transformation technologies.

## Business problem
Northstar Retail (fictional) operates physical stores and e-commerce. Its operational systems do not provide consistent definitions of sales, returns, gross profit, or customer retention. The platform creates reproducible, tested analytical models for executives, sales/category managers, CRM, and analysts.

## Scope
- Sales: gross sales, discounts, net sales, orders, units, AOV, monthly/yearly growth.
- Products/channels: category, SKU, store, channel, gross profit and gross margin.
- Customers: new/returning, purchase frequency, repeat purchase, cohort retention.
- Out of scope for MVP: inventory, forecasting, RFM, clustering, shipping costs, contribution margin, real-time streaming.

## Technology decisions
| Component | Choice | Reason |
|---|---|---|
| Relational persistence | PostgreSQL | SQL, DDL, constraints, joins, indexing, transactions, upserts |
| Local infrastructure | Docker Compose | Reproducible PostgreSQL service, healthcheck and named volume |
| Transformations | dbt-core + dbt-postgres | SQL models, DAG, documentation, tests, snapshots |
| Ingestion | Python + psycopg | Connections, batch/COPY loading, transaction handling |
| BI | Power BI, PostgreSQL Import connector | Direct database source, refreshable dimensional marts |
| Unit/CI testing | pytest + dbt tests + GitHub Actions | Repeatable verification with ephemeral PostgreSQL |

## Data flow and ownership
1. Synthetic source generator emits deterministic batches with source timestamps and source IDs.
2. Python ingestion loads batches into temporary landing structures, validates contracts, quarantines malformed records and upserts accepted rows into `raw`.
3. dbt builds `staging` (typed source normalization), `intermediate` (business logic), `marts` (facts/dimensions/cohorts) within PostgreSQL.
4. SQL reconciliation queries and dbt tests validate marts.
5. Power BI reads `marts` through the PostgreSQL connector; no CSV-based BI production dependency.

Database: `retail_analytics`; schemas: `raw`, `staging`, `intermediate`, `marts`, `control`. The orchestration process manages bootstrap and ingestion; dbt manages transformation order. Keep generated sample data and credentials separate from tracked source.

## Rebuild, incremental and validation interfaces (planned)
- `python -m src.orchestration.pipeline --mode rebuild`: check environment guard; start/wait for Docker PostgreSQL; create owned schemas and tables; regenerate source data; ingest; execute dbt; run quality/reconciliation; record status. Destructive actions limited to an explicitly identified local project database, never arbitrary volumes/databases.
- `--mode incremental`: ingest new/changed source records idempotently; rebuild affected marts initially; optimize with dbt incremental materializations only after correctness is demonstrated.
- `--mode validate`: run read-only quality and reconciliation queries; do not mutate business data. Test result logs can be written externally if strict read-only mode is desired.

Failure must return a nonzero process exit code; successful runs must produce row counts, rejected counts, validation results and duration. Never claim atomicity for the entire multi-step rebuild: define safe rerun behavior and rollback at each ingestion transaction boundary.

## Analytical design
Primary sales grain: one order item (`fct_order_items`); distinct orders derived by `order_id`. Returns are separate events (`fct_returns`) linked to original items. Dimensions: customer, product, store, channel, date. `mart_customer_cohorts` has one row per acquisition cohort and activity month. Historical transaction price/cost are stored on order items; changing catalog prices must not restate history.

Initial staging/intermediate models are views and marts are tables; revise materializations based on observed query plans and performance. Customer segment history is an optional scoped SCD2 demonstration: source must provide replayable changes; snapshots of only the latest state cannot reconstruct earlier history.

## Reproducibility and security
Pin compatible versions of Python/PostgreSQL/dbt dependencies at implementation. `.env.example` contains placeholders only. No secrets in Git. Docker uses a named volume and healthcheck. GitHub Actions uses a temporary PostgreSQL service and synthetic data. No real customer PII. Document setup for Windows, VS Code, Docker Desktop, Power BI Desktop, and GitHub Desktop.

## Architecture acceptance
- One command provisions a clean local database, ingests sources, builds marts and runs tests.
- Re-running a batch does not double count transactions.
- An incremental batch with late returns updates metrics correctly.
- Power BI connects to PostgreSQL marts.
- A clean CI runner reproduces database/model/test steps.
- All published dashboard metrics reconcile to executed SQL queries.
