select product_id, sku, product_name, category_id, list_price, standard_unit_cost, is_active from {{ ref('stg_products') }}
