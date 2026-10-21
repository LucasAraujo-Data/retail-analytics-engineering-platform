select * from {{ source('retail_raw', 'channels') }}
