select * from {{ source('retail_raw', 'order_items') }}
