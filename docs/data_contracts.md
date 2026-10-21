# Operational Data Contracts and Physical Model

**Status:** Phase 1 proposed schema; column names/types are implementation targets, not existing objects.  
**Database:** `retail_analytics` — schema `raw` for validated operational records.

## Common conventions
- Primary keys are source-assigned IDs, not regenerated on each load.
- Monetary values: `NUMERIC(14,2)` for aggregated payments, `NUMERIC(12,2)` for item-level values; no floating-point currency.
- Event times: `TIMESTAMPTZ` stored in UTC; business reporting calendar uses `America/Sao_Paulo`.
- Every upsert-capable entity carries `updated_at` or a source update timestamp. `order_items` are immutable after valid recognition in MVP; corrections require explicit controlled reprocessing.
- Raw tables represent validated current operational state; rejected payloads are retained in `control.rejected_records`.
- For foreign keys, parent entities load before children. Cross-record invariants that SQL CHECK cannot express are verified in ingestion/dbt tests.

## Tables and columns

### `raw.customers` — grain: one current customer
| Column | PostgreSQL type | Constraint / meaning |
|---|---|---|
| customer_id | BIGINT | PK |
| customer_created_at | TIMESTAMPTZ | NOT NULL |
| birth_year | SMALLINT | NULL; plausible range checked |
| customer_region | VARCHAR(50) | NOT NULL |
| acquisition_channel | VARCHAR(30) | NOT NULL; controlled domain |
| customer_segment | VARCHAR(30) | NOT NULL; controlled domain |
| updated_at | TIMESTAMPTZ | NOT NULL |

### `raw.categories` — grain: one category
| Column | Type | Constraint |
|---|---|---|
| category_id | INTEGER | PK |
| category_name | VARCHAR(100) | NOT NULL, UNIQUE |
| department_name | VARCHAR(100) | NOT NULL |
| is_active | BOOLEAN | NOT NULL |

### `raw.products` — grain: one SKU
| Column | Type | Constraint |
|---|---|---|
| product_id | BIGINT | PK |
| sku | VARCHAR(40) | NOT NULL, UNIQUE |
| product_name | VARCHAR(150) | NOT NULL |
| category_id | INTEGER | NOT NULL, FK categories |
| list_price | NUMERIC(12,2) | NOT NULL, >= 0 |
| standard_unit_cost | NUMERIC(12,2) | NOT NULL, >= 0 |
| is_active | BOOLEAN | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL |

### `raw.stores` — grain: one physical or virtual store
| Column | Type | Constraint |
|---|---|---|
| store_id | INTEGER | PK |
| store_name | VARCHAR(100) | NOT NULL |
| store_type | VARCHAR(20) | NOT NULL; PHYSICAL/ONLINE |
| region | VARCHAR(50) | NOT NULL |
| opening_date | DATE | NOT NULL |
| is_active | BOOLEAN | NOT NULL |

### `raw.channels` — grain: one selling channel
| Column | Type | Constraint |
|---|---|---|
| channel_id | SMALLINT | PK |
| channel_name | VARCHAR(30) | NOT NULL, UNIQUE; STORE/ECOMMERCE |
| channel_group | VARCHAR(30) | NOT NULL; PHYSICAL/DIGITAL |
| is_active | BOOLEAN | NOT NULL |

### `raw.orders` — grain: one order
| Column | Type | Constraint |
|---|---|---|
| order_id | BIGINT | PK |
| customer_id | BIGINT | NULL, FK customers |
| store_id | INTEGER | NOT NULL, FK stores |
| channel_id | SMALLINT | NOT NULL, FK channels |
| order_created_at | TIMESTAMPTZ | NOT NULL |
| order_status | VARCHAR(20) | NOT NULL; CREATED/CONFIRMED/FULFILLED/CANCELLED |
| order_updated_at | TIMESTAMPTZ | NOT NULL; >= created_at |
| source_system | VARCHAR(30) | NOT NULL; POS/ECOMMERCE |

### `raw.order_items` — grain: one order line
| Column | Type | Constraint |
|---|---|---|
| order_item_id | BIGINT | PK |
| order_id | BIGINT | NOT NULL, FK orders |
| product_id | BIGINT | NOT NULL, FK products |
| quantity | INTEGER | NOT NULL, > 0 |
| unit_list_price | NUMERIC(12,2) | NOT NULL, >= 0 |
| unit_selling_price | NUMERIC(12,2) | NOT NULL, >= 0 and <= list price |
| unit_cost | NUMERIC(12,2) | NOT NULL, >= 0 |
| line_discount_amount | NUMERIC(12,2) | NOT NULL, >= 0; must reconcile to quantity * price difference |
| created_at | TIMESTAMPTZ | NOT NULL |

### `raw.payments` — grain: one payment attempt
| Column | Type | Constraint |
|---|---|---|
| payment_id | BIGINT | PK |
| order_id | BIGINT | NOT NULL, FK orders |
| payment_method | VARCHAR(30) | NOT NULL; controlled domain |
| payment_status | VARCHAR(20) | NOT NULL; PENDING/APPROVED/FAILED/REFUNDED |
| payment_amount | NUMERIC(14,2) | NOT NULL, >= 0 |
| payment_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL |

### `raw.returns` — grain: one return event on an order line
| Column | Type | Constraint |
|---|---|---|
| return_id | BIGINT | PK |
| order_item_id | BIGINT | NOT NULL, FK order_items |
| return_quantity | INTEGER | NOT NULL, > 0 |
| return_amount | NUMERIC(12,2) | NOT NULL, >= 0 |
| return_status | VARCHAR(20) | NOT NULL; REQUESTED/APPROVED/REJECTED/COMPLETED |
| return_reason | VARCHAR(50) | NOT NULL; controlled domain |
| requested_at | TIMESTAMPTZ | NOT NULL |
| completed_at | TIMESTAMPTZ | NULL; required if COMPLETED |
| updated_at | TIMESTAMPTZ | NOT NULL |

## Referential relationships
`customers (0..1) → orders (many)`; `stores → orders`; `channels → orders`; `categories → products`; `orders → order_items`; `products → order_items`; `orders → payments`; `order_items → returns`. A NULL `orders.customer_id` represents an unidentified buyer; these orders remain eligible for sales metrics but not identified-customer retention.

## Technical control tables

### `control.pipeline_runs`
`run_id UUID PRIMARY KEY`, `run_mode VARCHAR(20) NOT NULL`, `started_at TIMESTAMPTZ NOT NULL`, `finished_at TIMESTAMPTZ NULL`, `run_status VARCHAR(20) NOT NULL`, `records_loaded BIGINT NOT NULL DEFAULT 0`, `records_rejected BIGINT NOT NULL DEFAULT 0`, `error_message TEXT NULL`. Domains: REBUILD/INCREMENTAL/VALIDATE and RUNNING/SUCCESS/FAILED.

### `control.rejected_records`
`rejection_id BIGINT PRIMARY KEY`, `run_id UUID NOT NULL REFERENCES control.pipeline_runs`, `source_table VARCHAR(100) NOT NULL`, `source_record_key VARCHAR(100)`, `error_code VARCHAR(50) NOT NULL`, `error_details TEXT NOT NULL`, `raw_payload JSONB NOT NULL`, `rejected_at TIMESTAMPTZ NOT NULL`.

## Ingestion contract
| Source | Business key | Update strategy | Rejection examples |
|---|---|---|---|
| customers | customer_id | Upsert by updated_at | missing ID, invalid timestamp |
| categories | category_id | Upsert | missing name |
| products | product_id | Upsert by updated_at | unknown category, negative price |
| stores | store_id | Upsert | invalid store type |
| channels | channel_id | Upsert | unknown channel |
| orders | order_id | Upsert by order_updated_at | unknown store/channel, illegal status transition |
| order_items | order_item_id | Insert / controlled correction | missing order/product, nonpositive quantity |
| payments | payment_id | Upsert by updated_at | unknown order, negative amount |
| returns | return_id | Upsert by updated_at | unknown item, excess cumulative quantity |

For equal update timestamps with conflicting payloads, reject as ambiguous rather than choose an arbitrary winner. Out-of-order older updates must not overwrite newer accepted state. Replays of identical batches must be no-ops.

## Data generation contract
Synthetic only, fixed random seed, approximately 24 months, 100k orders, 250–350k items, 20–35k customers, 500–1000 products, 15–25 physical stores plus virtual store. These are targets, not observed results. Generate seasonality, cohort behavior, repeat purchases, channel differences, partial returns, late events and controlled bad records. Every metric or insight must be computed from generated/loaded data, never hard-coded as an outcome.
