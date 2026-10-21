select store_id, store_name, store_type, region, opening_date, is_active from {{ ref('stg_stores') }}
