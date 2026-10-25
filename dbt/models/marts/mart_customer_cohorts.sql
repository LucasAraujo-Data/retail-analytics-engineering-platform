
-- Grain: one row per acquisition cohort and months since first purchase.
-- Retention is based on distinct customers with eligible purchases.
-- Month 0 represents the acquisition month.

with customer_monthly_activity as (

    select distinct
        customer_id,
        date_trunc(
            'month',
            order_created_at at time zone 'America/Sao_Paulo'
        )::date as purchase_month

    from {{ ref('fct_order_items') }}

    where customer_id is not null

),

first_purchase as (

    select
        customer_id,
        min(purchase_month) as cohort_month

    from customer_monthly_activity

    group by customer_id

),

customer_retention as (

    select
        f.cohort_month,
        a.purchase_month,
        (
            extract(year from age(a.purchase_month, f.cohort_month)) * 12
            + extract(month from age(a.purchase_month, f.cohort_month))
        )::integer as months_since_first_purchase,
        a.customer_id

    from customer_monthly_activity a

    inner join first_purchase f
        on a.customer_id = f.customer_id

),

cohort_sizes as (

    select
        cohort_month,
        count(distinct customer_id) as cohort_size

    from first_purchase

    group by cohort_month

),

monthly_retention as (

    select
        cohort_month,
        months_since_first_purchase,
        count(distinct customer_id) as retained_customers

    from customer_retention

    group by
        cohort_month,
        months_since_first_purchase

)

select
    r.cohort_month,
    r.months_since_first_purchase,
    c.cohort_size,
    r.retained_customers,
    round(
        100.0 * r.retained_customers / nullif(c.cohort_size, 0),
        2
    ) as retention_rate_pct

from monthly_retention r

inner join cohort_sizes c
    on r.cohort_month = c.cohort_month
