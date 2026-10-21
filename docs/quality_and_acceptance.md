# Data Quality, Rebuild and Acceptance Specification

**Status:** Proposed test plan; no tests have been executed yet.

## Test layers
1. **PostgreSQL constraints:** PK, FK, NOT NULL, UNIQUE, CHECK for local row invariants.
2. **Ingestion validation:** schema/types, domain checks, duplicate/conflicting updates, parent lookup, cross-row amount/quantity constraints; quarantine malformed records with run ID and payload.
3. **dbt generic tests:** uniqueness, not_null, relationships, accepted_values, source freshness where applicable.
4. **dbt singular tests / SQL reconciliation:** payment-to-order totals, discount arithmetic, cumulative returns, mart-vs-raw totals, cohort membership, SCD2 non-overlap.
5. **pytest:** deterministic generation, connection failures, idempotent upserts, transactional rollback, orchestration exit codes, safe rebuild guards.
6. **CI integration:** clean PostgreSQL service, small seeded dataset, rebuild, incremental replay, validation.

## Matrix by entity
| Entity | Mandatory validations |
|---|---|
| customers | unique ID, created <= updated, segment domain, optional birth year plausible |
| categories | unique ID/name, nonempty department |
| products | unique ID/SKU, category FK, nonnegative prices/cost |
| stores | unique ID, type domain, opening date valid |
| channels | unique ID/name, channel group domain |
| orders | unique ID, customer/store/channel FKs, status domain, update chronology, valid channel/store combination |
| order_items | unique ID, order/product FKs, positive quantity, valid unit prices, discount reconciliation |
| payments | unique ID, order FK, status/method domains, no more than one approved payment, approved amount reconciles |
| returns | unique ID, item FK, status domain, completion chronology, cumulative quantity and refund limits |
| pipeline_runs | valid mode/status, timestamps, nonnegative counts |
| rejected_records | FK run ID, nonempty error code, valid JSON payload |
| marts | unique dimensional keys, no orphan facts, grain consistency, sales/returns/COGS reconciled |

## Acceptance scenarios
**A. Fresh rebuild:** From a clean project database, provision service, create schema, ingest data, build dbt models, run tests; exit success; log table counts and duration.

**B. Replay idempotency:** Run the same batch twice; operational and mart row counts, net sales and returns must be unchanged.

**C. Incremental update:** Load new orders, changed statuses and a late completed return; only legitimate differences appear in financial totals; original-order and event-period reports each follow their documented time logic.

**D. Controlled bad data:** Inject duplicate keys, missing parents, invalid price, over-return, and conflicting same-timestamp updates. Invalid records are quarantined; no silent truncation or coercion; severity policy determines whether batch continues or fails.

**E. Rollback:** Force a load error mid-transaction; partially loaded batch is not committed; failure recorded; rerun can recover safely.

**F. CI reproducibility:** GitHub Actions provisions temporary PostgreSQL, installs pinned dependencies, runs the pipeline on a small deterministic fixture and fails if any required check fails.

**G. Power BI:** PostgreSQL Import connection to `marts` works; key KPI values match independent SQL checks. Screenshots and published insights must reflect actual computed results.

## Definition of done
- Clean install and rebuild documented for Windows + Docker Desktop + VS Code.
- Database DDL, constraints, schema ownership and source contracts versioned.
- dbt project builds and documents its DAG, with all mandatory tests passing.
- At least one incremental batch and late-return scenario demonstrated.
- Rebuild guard prevents unintended destructive actions outside the named local database.
- Credentials excluded from repository; sample config supplied.
- CI runs without paid services or external private datasets.
- README and architecture/contract/business-rule documentation in English.

## Implementation sequencing
1. Finalize open schema questions, especially `recognized_at` and SCD2 event history.
2. Pin dependency versions; create Compose service and bootstrap DDL.
3. Implement deterministic generator and ingest/validation contracts.
4. Implement dbt staging, intermediate and marts.
5. Add financial reconciliations and integration tests.
6. Implement incremental behavior and CI.
7. Build Power BI and publish verified screenshots/insights.
