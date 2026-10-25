select
    p.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    c.category_name,
    p.list_price,
    p.standard_unit_cost,
    p.is_active
from {{ ref('stg_products') }} as p
left join {{ ref('stg_categories') }} as c
    on p.category_id = c.category_id