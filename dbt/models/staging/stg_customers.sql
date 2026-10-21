select * from {{ source('retail_raw', 'customers') }}
