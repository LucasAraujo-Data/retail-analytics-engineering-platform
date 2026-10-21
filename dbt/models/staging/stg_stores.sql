select * from {{ source('retail_raw', 'stores') }}
