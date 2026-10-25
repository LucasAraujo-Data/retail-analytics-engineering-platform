
with returned_items as (

    select
        order_item_id,
        sum(return_quantity) as returned_units

    from {{ ref('fct_returns') }}

    where return_status = 'COMPLETED'

    group by order_item_id

)

select
    r.order_item_id,
    r.returned_units,
    i.quantity as sold_units

from returned_items r

left join {{ ref('fct_order_items') }} i
    on r.order_item_id = i.order_item_id

where
    i.order_item_id is null
    or r.returned_units > i.quantity
