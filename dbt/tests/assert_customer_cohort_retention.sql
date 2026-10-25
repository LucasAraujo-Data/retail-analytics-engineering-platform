
with cohorts as (

    select
        cohort_month,
        months_since_first_purchase,
        cohort_size,
        retained_customers,
        retention_rate_pct

    from {{ ref('mart_customer_cohorts') }}

),

duplicate_cohort_months as (

    select
        cohort_month,
        months_since_first_purchase

    from cohorts

    group by
        cohort_month,
        months_since_first_purchase

    having count(*) > 1

)

select
    c.*

from cohorts c

left join duplicate_cohort_months d
    on c.cohort_month = d.cohort_month
    and c.months_since_first_purchase = d.months_since_first_purchase

where
    d.cohort_month is not null
    or c.cohort_month is null
    or c.months_since_first_purchase is null
    or c.months_since_first_purchase < 0
    or c.cohort_size is null
    or c.cohort_size <= 0
    or c.retained_customers is null
    or c.retained_customers < 0
    or c.retained_customers > c.cohort_size
    or c.retention_rate_pct is null
    or c.retention_rate_pct < 0
    or c.retention_rate_pct > 100
    or abs(
        c.retention_rate_pct
        - round(
            100.0 * c.retained_customers
            / nullif(c.cohort_size, 0),
            2
        )
    ) > 0.01
    or (
        c.months_since_first_purchase = 0
        and (
            c.retained_customers <> c.cohort_size
            or c.retention_rate_pct <> 100
        )
    )
