select customer_id, customer_created_at, birth_year, customer_region, acquisition_channel, customer_segment from {{ ref('stg_customers') }}
