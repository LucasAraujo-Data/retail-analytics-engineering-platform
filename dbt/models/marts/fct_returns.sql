-- Grain: one row per return event, restricted to eligible sales.
select
  r.return_id, r.order_item_id, i.order_id, i.product_id,
  r.return_quantity, r.return_amount, r.return_status,
  r.requested_at, r.completed_at,
  case when r.return_status = 'COMPLETED' then r.return_amount else 0::numeric end as completed_return_amount
from {{ ref('stg_returns') }} r
join {{ ref('fct_order_items') }} i using (order_item_id)
