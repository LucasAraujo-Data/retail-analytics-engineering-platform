# Business Rules and Metric Definitions

**Status:** Phase 1 baseline. All reporting labels and SQL definitions must match these conventions.

## Sale eligibility
A sale is recognized when `orders.order_status IN ('CONFIRMED','FULFILLED')` and the order has exactly one approved payment equal to the order's sum of discounted line values (MVP assumption). `CREATED` and `CANCELLED` orders are excluded. Cancelled orders must not have previously recognized sales; post-recognition reversals use returns. Multiple failed/pending payment attempts are allowed, but at most one approved attempt per order.

## Monetary formulas (per eligible line)
- `gross_sales = quantity * unit_list_price`
- `discount_amount = line_discount_amount = quantity * (unit_list_price - unit_selling_price)`
- `sales_after_discount = quantity * unit_selling_price`
- `original_cogs = quantity * unit_cost`
- `completed_return_amount = SUM(return_amount WHERE return_status = 'COMPLETED')`
- `returned_cogs = SUM(return_quantity * original unit_cost WHERE COMPLETED)`
- `net_sales = sales_after_discount - completed_return_amount`
- `net_cogs = original_cogs - returned_cogs`
- `gross_profit = net_sales - net_cogs`
- `gross_margin_pct = gross_profit / net_sales` when net_sales != 0; otherwise NULL.

For MVP, completed returns refund returned quantity at the original unit selling price and returned goods are restockable. A line's cumulative completed return quantity cannot exceed original quantity. All calculations use exact decimal types with explicit rounding policy. Do not label gross profit as contribution margin.

## Time perspectives
- **Order-origin perspective:** assign sales and all subsequent completed returns to the original sale date; useful for original order/product profitability and cohorts. Historical periods can be restated after late returns.
- **Event-period perspective:** recognize positive sales on their eligible recognition date and subtract completed returns on their completion date; executive reporting uses this perspective. A month can have negative net sales if late returns exceed new sales.
- All business dates are derived from UTC timestamps using `America/Sao_Paulo` consistently.

**Design dependency to resolve before coding:** the current `raw.orders` schema has `order_created_at` and status but no explicit `recognized_at`. Add a durable recognition timestamp or a reliable status-event source before implementing event-period reporting; do not infer recognition date from the current status alone. Similarly, refund completion must be distinguished from payment-attempt status. This is a required schema refinement in the physical-design review.

## Orders and AOV
`orders = COUNT(DISTINCT order_id)` for eligible recognized orders in the reporting period. `average_order_value = net_sales / orders` if orders > 0; NULL otherwise. Explain that returns from earlier periods can reduce event-period AOV; consider reporting a sales-only AOV alongside it if stakeholder interpretation requires.

## Customer metrics
- **New customer:** identified customer with first eligible purchase recognized in the reporting period.
- **Returning customer:** identified customer purchasing in the period with an earlier eligible purchase.
- **Purchase frequency:** eligible orders / distinct identified purchasing customers.
- **Repeat purchase rate:** identified customers with at least two eligible purchases / defined eligible identified customer population; always state the observation window and denominator.
- **Cohort:** month of first eligible purchase. Retention in month N = cohort customers with an eligible purchase in month N / original cohort size. Future unobserved months are NULL/not shown, never zero.
- Unidentified orders contribute to sales but not identified-customer KPIs.

## Quality invariants
1. PKs unique and not null; required FKs resolve.
2. One approved payment per recognized order, and its amount reconciles to discounted order lines.
3. `0 <= unit_selling_price <= unit_list_price`, positive quantities, nonnegative costs and discounts.
4. Line discounts reconcile to unit price differences.
5. Sum of completed return quantities <= sold quantity for each order item.
6. Completed returns require `completed_at >= requested_at`; non-completed returns do not reduce revenue.
7. Sales, returns and gross profit reconcile from item-level records to marts.
8. Rerunning identical batch does not change row counts or financial totals.
9. Late returns update the correct order-origin and event-period aggregates.
10. SCD2 intervals (if enabled) cannot overlap for one customer; each sale maps to exactly one applicable dimension version.

## Open design decisions before implementation
- Add recognition timestamp/status event data to the operational contract.
- Specify the precise definition of a valid customer purchase after a full return (for cohort purposes).
- Determine whether `customer_segment` source changes will be replayed as events or whether SCD2 will be deferred.
- Define exact payment-method and return-reason domains, rounding edge cases, and source correction policy.
