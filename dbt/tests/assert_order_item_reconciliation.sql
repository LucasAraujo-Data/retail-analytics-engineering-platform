select order_item_id
from {{ ref('fct_order_items') }}
where gross_sales_amount - line_discount_amount <> sales_amount
   or quantity <= 0
