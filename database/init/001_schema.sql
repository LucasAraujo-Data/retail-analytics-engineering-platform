-- Initial database bootstrap. Runs automatically ONLY on first initialization
-- of an empty PostgreSQL data volume. Future schema changes require migrations.
BEGIN;
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS control;

CREATE TABLE raw.customers (
  customer_id BIGINT PRIMARY KEY,
  customer_created_at TIMESTAMPTZ NOT NULL,
  birth_year SMALLINT CHECK (birth_year BETWEEN 1900 AND 2100),
  customer_region VARCHAR(50) NOT NULL,
  acquisition_channel VARCHAR(30) NOT NULL,
  customer_segment VARCHAR(30) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT customers_updated_after_created CHECK (updated_at >= customer_created_at)
);
CREATE TABLE raw.categories (
  category_id INTEGER PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL UNIQUE,
  department_name VARCHAR(100) NOT NULL,
  is_active BOOLEAN NOT NULL
);
CREATE TABLE raw.products (
  product_id BIGINT PRIMARY KEY,
  sku VARCHAR(40) NOT NULL UNIQUE,
  product_name VARCHAR(150) NOT NULL,
  category_id INTEGER NOT NULL REFERENCES raw.categories(category_id),
  list_price NUMERIC(12,2) NOT NULL CHECK (list_price >= 0),
  standard_unit_cost NUMERIC(12,2) NOT NULL CHECK (standard_unit_cost >= 0),
  is_active BOOLEAN NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE raw.stores (
  store_id INTEGER PRIMARY KEY,
  store_name VARCHAR(100) NOT NULL,
  store_type VARCHAR(20) NOT NULL CHECK (store_type IN ('PHYSICAL','ONLINE')),
  region VARCHAR(50) NOT NULL,
  opening_date DATE NOT NULL,
  is_active BOOLEAN NOT NULL
);
CREATE TABLE raw.channels (
  channel_id SMALLINT PRIMARY KEY,
  channel_name VARCHAR(30) NOT NULL UNIQUE CHECK (channel_name IN ('STORE','ECOMMERCE')),
  channel_group VARCHAR(30) NOT NULL CHECK (channel_group IN ('PHYSICAL','DIGITAL')),
  is_active BOOLEAN NOT NULL
);
CREATE TABLE raw.orders (
  order_id BIGINT PRIMARY KEY,
  customer_id BIGINT REFERENCES raw.customers(customer_id),
  store_id INTEGER NOT NULL REFERENCES raw.stores(store_id),
  channel_id SMALLINT NOT NULL REFERENCES raw.channels(channel_id),
  order_created_at TIMESTAMPTZ NOT NULL,
  order_status VARCHAR(20) NOT NULL CHECK (order_status IN ('CREATED','CONFIRMED','FULFILLED','CANCELLED')),
  order_updated_at TIMESTAMPTZ NOT NULL,
  source_system VARCHAR(30) NOT NULL CHECK (source_system IN ('POS','ECOMMERCE')),
  CONSTRAINT orders_updated_after_created CHECK (order_updated_at >= order_created_at)
);
CREATE TABLE raw.order_items (
  order_item_id BIGINT PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES raw.orders(order_id),
  product_id BIGINT NOT NULL REFERENCES raw.products(product_id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_list_price NUMERIC(12,2) NOT NULL CHECK (unit_list_price >= 0),
  unit_selling_price NUMERIC(12,2) NOT NULL CHECK (unit_selling_price >= 0),
  unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
  line_discount_amount NUMERIC(12,2) NOT NULL CHECK (line_discount_amount >= 0),
  created_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT selling_price_not_above_list CHECK (unit_selling_price <= unit_list_price),
  CONSTRAINT discount_reconciles CHECK (line_discount_amount = quantity * (unit_list_price - unit_selling_price))
);
CREATE TABLE raw.payments (
  payment_id BIGINT PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES raw.orders(order_id),
  payment_method VARCHAR(30) NOT NULL,
  payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('PENDING','APPROVED','FAILED','REFUNDED')),
  payment_amount NUMERIC(14,2) NOT NULL CHECK (payment_amount >= 0),
  payment_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL CHECK (updated_at >= payment_at)
);
CREATE TABLE raw.returns (
  return_id BIGINT PRIMARY KEY,
  order_item_id BIGINT NOT NULL REFERENCES raw.order_items(order_item_id),
  return_quantity INTEGER NOT NULL CHECK (return_quantity > 0),
  return_amount NUMERIC(12,2) NOT NULL CHECK (return_amount >= 0),
  return_status VARCHAR(20) NOT NULL CHECK (return_status IN ('REQUESTED','APPROVED','REJECTED','COMPLETED')),
  return_reason VARCHAR(50) NOT NULL,
  requested_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT completed_return_has_date CHECK (return_status <> 'COMPLETED' OR completed_at IS NOT NULL),
  CONSTRAINT return_chronology CHECK (completed_at IS NULL OR completed_at >= requested_at),
  CONSTRAINT return_updated_after_request CHECK (updated_at >= requested_at)
);
CREATE TABLE control.pipeline_runs (
  run_id UUID PRIMARY KEY,
  run_mode VARCHAR(20) NOT NULL CHECK (run_mode IN ('REBUILD','INCREMENTAL','VALIDATE')),
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ,
  run_status VARCHAR(20) NOT NULL CHECK (run_status IN ('RUNNING','SUCCESS','FAILED')),
  records_loaded BIGINT NOT NULL DEFAULT 0 CHECK (records_loaded >= 0),
  records_rejected BIGINT NOT NULL DEFAULT 0 CHECK (records_rejected >= 0),
  error_message TEXT,
  CONSTRAINT run_chronology CHECK (finished_at IS NULL OR finished_at >= started_at)
);
CREATE TABLE control.rejected_records (
  rejection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id UUID NOT NULL REFERENCES control.pipeline_runs(run_id),
  source_table VARCHAR(100) NOT NULL,
  source_record_key VARCHAR(100),
  error_code VARCHAR(50) NOT NULL,
  error_details TEXT NOT NULL,
  raw_payload JSONB NOT NULL,
  rejected_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMIT;
