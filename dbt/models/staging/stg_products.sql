select * from {{ source('retail_raw', 'products') }}
