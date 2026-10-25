
-- Grain: one row per return event, restricted to eligible sales.
-- Return measures can be analyzed by the original sale date.

select
    r.return_id,
    r.order_item_id,
    i.order_id,
    i.customer_id,
    i.store_id,
    i.channel_id,
    i.product_id,

    i.order_created_at,
    i.order_created_at::date as order_date,

    r.return_quantity,
    r.return_amount,
    r.return_status,
    r.requested_at,
    r.completed_at,

    i.unit_cost,

    case
        when r.return_status = 'COMPLETED'
        then r.return_amount
        else 0::numeric
    end as completed_return_amount,

    case
        when r.return_status = 'COMPLETED'
        then (r.return_quantity * i.unit_cost)::numeric(14,2)
        else 0::numeric
    end as completed_return_cost

from {{ ref('stg_returns') }} r

inner join {{ ref('fct_order_items') }} i
    on r.order_item_id = i.order_item_id
