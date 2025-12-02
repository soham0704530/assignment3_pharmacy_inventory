# Report Summary — Pharmacy & Inventory Analytics

## Executive Summary
This analysis examines pharmacy sales, inventory purchases, supplier performance, margins, and expiry risk. Key deliverables include monthly revenue tables, top medicines by quantity and revenue, near-expiry batches, supplier summary, margin analysis, revenue by customer/payment type, stock movement, and high-discount impact.

## Top Insights (example outputs you should validate)
1. Top 3 medicines account for ~X% of net revenue — indicates concentration in a few SKUs. (Replace X with actual number from `outputs/top_medicines_revenue.csv`.)
2. Y batches (from `outputs/near_expiry_batches.csv`) are expiring within 60 days with remaining stock > 0 — urgent markdowns or returns recommended. (Replace Y with actual.)
3. Supplier Z supplies the single highest purchase value and contributes N distinct SKUs; consider negotiating volume discounts for high-value suppliers.
4. Several medicines show high average discount percentage (>A%) while margin is low — discounts may be hurting profitability. (Replace A with actual.)
5. Monthly net revenue trend shows seasonality with peaks in [months], suggesting promotional planning windows.

## Actionable Recommendations
1. **Urgent promotions:** Run targeted discounts/BOGO on near-expiry batches to reduce expiry losses; prioritize high-margin SKUs if possible.
2. **Reorder policy:** For top-moving SKUs (top 10 by qty), set safety stock and reorder points using average weekly demand and lead time (calculate using stock movement output).
3. **Supplier negotiation:** For suppliers contributing the most purchase value but with low on-time delivery or high returns, negotiate better prices or diversify suppliers to reduce concentration risk.
4. **Discount optimization:** Reduce blanket discounting for items with already low margin; instead use targeted, time-bound offers that aim to increase profitable volume.
5. **Data hygiene:** Investigate sale items with no matching purchase batch and implement a consistent strategy for purchase price fallback (e.g., latest purchase price or median recent purchase price).

## Assumptions & Limitations
- GST is computed using `Medicine.gst_percentage` and applied as `selling_price * qty * gst_pct/100`.
- Net revenue defined as: gross (price × qty) − discount + GST. If GST is included in price in your data, adjust the formula accordingly.
- Margin is computed using matched Purchase_Stock.purchase_price via batch_no. If batch mapping is missing, results for margin may be incomplete.
- Date/timezones: all date operations assume DB dates are consistent; normalize to a single timezone if necessary.

## Next steps (optional improvements)
- Add time-series forecasting per SKU to predict demand and optimize purchase orders.
- Build a Streamlit dashboard for live monitoring of expiry risk and reorder alerts.
- Implement ETL pipeline to refresh aggregates and drive automated reorder emails.

