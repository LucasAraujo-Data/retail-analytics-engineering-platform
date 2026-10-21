select * from {{ source('retail_raw', 'payments') }}
