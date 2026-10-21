-- An order is eligible only if it is confirmed/fulfilled and has an approved payment.
-- EXISTS prevents multiplying order lines when there are multiple payments.
select o.*
from {{ ref('stg_orders') }} o
where o.order_status in ('CONFIRMED', 'FULFILLED')
  and exists (
    select 1
    from {{ ref('stg_payments') }} p
    where p.order_id = o.order_id and p.payment_status = 'APPROVED'
  )
