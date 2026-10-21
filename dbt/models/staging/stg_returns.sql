select * from {{ source('retail_raw', 'returns') }}
