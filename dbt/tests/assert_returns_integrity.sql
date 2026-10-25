
-- Fails when a return has invalid quantities, amounts,
-- or inconsistent completed-return calculations.

select
    return_id,
    return_status,
    return_quantity,
    return_amount,
    completed_return_amount,
    completed_return_cost
from {{ ref('fct_returns') }}
where
    return_id is null
    or order_item_id is null
    or return_status is null
    or return_quantity is null
    or return_quantity <= 0
    or return_amount is null
    or return_amount < 0
    or completed_return_amount is null
    or completed_return_cost is null
    or completed_return_cost < 0
    or (
        return_status = 'COMPLETED'
        and completed_return_amount <> return_amount
    )
    or (
        return_status <> 'COMPLETED'
        and (
            completed_return_amount <> 0
            or completed_return_cost <> 0
        )
    )
