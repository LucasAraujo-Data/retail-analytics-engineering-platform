-- Grain: one row per eligible order item.
select
  i.order_item_id, i.order_id, o.customer_id, o.store_id, o.channel_id,
  i.product_id, o.order_created_at, i.quantity,
  i.unit_list_price, i.unit_selling_price, i.unit_cost,
  i.line_discount_amount,
  (i.quantity * i.unit_list_price)::numeric(14,2) as gross_sales_amount,
  (i.quantity * i.unit_selling_price)::numeric(14,2) as sales_amount,
  (i.quantity * i.unit_cost)::numeric(14,2) as cost_amount,
  (i.quantity * (i.unit_selling_price - i.unit_cost))::numeric(14,2) as gross_profit_before_returns
from {{ ref('stg_order_items') }} i
join {{ ref('int_eligible_orders') }} o using (order_id)
