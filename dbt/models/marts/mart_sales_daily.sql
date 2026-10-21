-- Sales and returns aggregated separately to avoid fan-out.
with sales as (
  select (order_created_at at time zone 'America/Sao_Paulo')::date as sales_date,
         count(distinct order_id) as orders,
         sum(quantity) as units,
         sum(gross_sales_amount) as gross_sales_amount,
         sum(line_discount_amount) as discount_amount,
         sum(sales_amount) as sales_amount,
         sum(cost_amount) as cost_amount
  from {{ ref('fct_order_items') }}
  group by 1
),
returns as (
  select (r.completed_at at time zone 'America/Sao_Paulo')::date as return_date,
         sum(r.completed_return_amount) as completed_return_amount
  from {{ ref('fct_returns') }} r
  where r.return_status = 'COMPLETED'
  group by 1
),
all_dates as (
  select sales_date as metric_date from sales
  union
  select return_date as metric_date from returns
)
select d.metric_date,
       coalesce(s.orders,0) as orders,
       coalesce(s.units,0) as units,
       coalesce(s.gross_sales_amount,0) as gross_sales_amount,
       coalesce(s.discount_amount,0) as discount_amount,
       coalesce(s.sales_amount,0) as sales_amount,
       coalesce(r.completed_return_amount,0) as completed_return_amount,
       coalesce(s.sales_amount,0)-coalesce(r.completed_return_amount,0) as net_sales_amount,
       coalesce(s.cost_amount,0) as cost_amount
from all_dates d
left join sales s on d.metric_date=s.sales_date
left join returns r on d.metric_date=r.return_date
