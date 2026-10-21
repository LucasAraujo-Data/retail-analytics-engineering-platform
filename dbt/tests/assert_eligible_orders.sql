select f.order_item_id
from {{ ref('fct_order_items') }} f
join {{ ref('stg_orders') }} o on o.order_id = f.order_id
where o.order_status not in ('CONFIRMED','FULFILLED')
   or not exists (
      select 1 from {{ ref('stg_payments') }} p
      where p.order_id = o.order_id and p.payment_status = 'APPROVED'
   )
