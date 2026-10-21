select * from {{ source('retail_raw', 'categories') }}
