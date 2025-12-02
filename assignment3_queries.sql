-- ==================================================================================
-- Assignment 3 – Pharmacy & Inventory Analytics
-- SQL file: assignment3_queries.sql
-- DB: assumed PostgreSQL (ANSI SQL). Replace date functions if using another engine.
-- Instructions: Each section below contains the query and a 2-3 line explanation.
-- Replace :start_date and :end_date placeholders with actual dates (e.g. '2025-01-01').
-- ==================================================================================

-- =====================================================================
-- Helper: Show tables in public schema (useful to inspect schema)
-- =====================================================================
-- Quick way to list tables to confirm table names before running queries.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- =====================================================================
-- Helper: Sample rows from each table (run separately for each table)
-- =====================================================================
-- Check first 5 rows to confirm column names and types for each core table.
-- Run separately: replace <TableName> with Medicine, Supplier, Purchase_Stock, Pharmacy_Sale, Pharmacy_Sale_Item
SELECT * FROM Medicine LIMIT 5;
SELECT * FROM Supplier LIMIT 5;
SELECT * FROM Purchase_Stock LIMIT 5;
SELECT * FROM Pharmacy_Sale LIMIT 5;
SELECT * FROM Pharmacy_Sale_Item LIMIT 5;

-- =====================================================================
-- 0. Data quality checks (nulls, negatives, date ranges)
-- =====================================================================
-- Basic checks to identify immediate data issues: missing PKs, negatives, and date ranges.
SELECT 'medicine_id_null' AS check_name, COUNT(*) AS cnt FROM Medicine WHERE medicine_id IS NULL;
SELECT 'supplier_id_null' AS check_name, COUNT(*) AS cnt FROM Supplier WHERE supplier_id IS NULL;
SELECT 'negative_purchase_qty' AS check_name, COUNT(*) AS cnt FROM Purchase_Stock WHERE purchase_quantity < 0;
SELECT 'negative_sell_qty' AS check_name, COUNT(*) AS cnt FROM Pharmacy_Sale_Item WHERE sold_quantity < 0;
SELECT MIN(sale_datetime) AS first_sale, MAX(sale_datetime) AS last_sale FROM Pharmacy_Sale;

-- =====================================================================
-- 1. Monthly revenue: gross, total_discount, total_gst, net_revenue
-- =====================================================================
-- Explanation:
-- Group sales by month, compute gross (selling_price * quantity), total discounts,
-- GST using medicine.gst_percentage, then net = gross - discount + gst.
SELECT
  DATE_TRUNC('month', s.sale_datetime)::date AS month_start,
  SUM(si.selling_price * si.sold_quantity) AS gross_revenue,
  SUM(si.discount_amount) AS total_discount,
  SUM(si.selling_price * si.sold_quantity * (m.gst_percentage/100.0)) AS total_gst,
  SUM(si.selling_price * si.sold_quantity) - COALESCE(SUM(si.discount_amount),0)
    + COALESCE(SUM(si.selling_price * si.sold_quantity * (m.gst_percentage/100.0)),0) AS net_revenue
FROM Pharmacy_Sale s
JOIN Pharmacy_Sale_Item si ON s.sale_id = si.sale_id
JOIN Medicine m ON si.medicine_id = m.medicine_id
GROUP BY DATE_TRUNC('month', s.sale_datetime)
ORDER BY month_start;

-- =====================================================================
-- 2a. Top 10 medicines by total quantity sold
-- =====================================================================
-- Explanation:
-- Aggregate sold_quantity per medicine and order descending to get top-selling medicines by units.
SELECT
  m.medicine_id,
  m.name,
  SUM(si.sold_quantity) AS total_qty_sold
FROM Pharmacy_Sale_Item si
JOIN Medicine m ON si.medicine_id = m.medicine_id
GROUP BY m.medicine_id, m.name
ORDER BY total_qty_sold DESC
LIMIT 10;

-- =====================================================================
-- 2b. Top 10 medicines by total net revenue
-- =====================================================================
-- Explanation:
-- Aggregate net revenue per medicine: selling_price*qty - discount + gst; then order by revenue.
SELECT
  m.medicine_id,
  m.name,
  SUM(si.selling_price * si.sold_quantity
      - COALESCE(si.discount_amount,0)
      + si.selling_price * si.sold_quantity * (COALESCE(m.gst_percentage,0)/100.0)
  ) AS total_net_revenue
FROM Pharmacy_Sale_Item si
JOIN Medicine m ON si.medicine_id = m.medicine_id
GROUP BY m.medicine_id, m.name
ORDER BY total_net_revenue DESC
LIMIT 10;

-- =====================================================================
-- 3. Near-expiry stock within next 60 days (remaining quantity per batch)
-- =====================================================================
-- Explanation:
-- For batches expiring in the next 60 days compute remaining_qty = purchase_quantity - sold_quantity (for that batch).
SELECT
  ps.batch_no,
  ps.medicine_id,
  COALESCE(m.name, 'UNKNOWN') AS medicine_name,
  ps.expiry_date,
  ps.purchase_quantity AS purchased_qty,
  COALESCE(SUM(si.sold_quantity), 0) AS sold_qty,
  (ps.purchase_quantity - COALESCE(SUM(si.sold_quantity), 0)) AS remaining_qty
FROM Purchase_Stock ps
LEFT JOIN Pharmacy_Sale_Item si
  ON ps.batch_no = si.batch_no AND ps.medicine_id = si.medicine_id
LEFT JOIN Medicine m ON ps.medicine_id = m.medicine_id
WHERE ps.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '60 days')
GROUP BY ps.batch_no, ps.medicine_id, m.name, ps.expiry_date, ps.purchase_quantity
HAVING (ps.purchase_quantity - COALESCE(SUM(si.sold_quantity),0)) > 0
ORDER BY ps.expiry_date ASC;

-- =====================================================================
-- 4. Supplier performance summary
-- =====================================================================
-- Explanation:
-- Aggregate purchase stock by supplier: total qty, total purchase value, distinct medicines, average purchase price.
-- Additionally identify the top medicine by quantity supplied per supplier using a window function.
WITH supplier_stats AS (
  SELECT
    ps.supplier_id,
    SUM(ps.purchase_quantity) AS total_qty_supplied,
    SUM(ps.purchase_quantity * ps.purchase_price) AS total_purchase_value,
    COUNT(DISTINCT ps.medicine_id) AS distinct_medicines_supplied,
    AVG(ps.purchase_price) AS avg_purchase_price
  FROM Purchase_Stock ps
  GROUP BY ps.supplier_id
),
top_meds AS (
  SELECT
    ps.supplier_id,
    ps.medicine_id,
    SUM(ps.purchase_quantity) AS qty_supplied,
    ROW_NUMBER() OVER (PARTITION BY ps.supplier_id ORDER BY SUM(ps.purchase_quantity) DESC) AS rn
  FROM Purchase_Stock ps
  GROUP BY ps.supplier_id, ps.medicine_id
)
SELECT
  ss.supplier_id,
  COALESCE(sup.supplier_name,'UNKNOWN') AS supplier_name,
  ss.total_qty_supplied,
  ss.total_purchase_value,
  ss.distinct_medicines_supplied,
  ss.avg_purchase_price,
  tm.medicine_id AS top_medicine_id,
  COALESCE(m.name,'UNKNOWN') AS top_medicine_name,
  tm.qty_supplied AS top_medicine_qty
FROM supplier_stats ss
LEFT JOIN Supplier sup ON ss.supplier_id = sup.supplier_id
LEFT JOIN (
  SELECT supplier_id, medicine_id, qty_supplied
  FROM top_meds WHERE rn = 1
) tm ON ss.supplier_id = tm.supplier_id
LEFT JOIN Medicine m ON tm.medicine_id = m.medicine_id
ORDER BY ss.total_purchase_value DESC;

-- =====================================================================
-- 5. Margin analysis per medicine (avg margin % and total gross profit)
-- =====================================================================
-- Explanation:
-- Match Pharmacy_Sale_Item to Purchase_Stock using batch_no and medicine_id to compute per-unit profit.
-- Aggregate to compute total gross profit, total units sold, and average margin percentage relative to revenue.
SELECT
  m.medicine_id,
  m.name,
  SUM((si.selling_price - COALESCE(ps.purchase_price,0)) * si.sold_quantity) AS total_gross_profit,
  SUM(si.sold_quantity) AS total_units_sold,
  (SUM((si.selling_price - COALESCE(ps.purchase_price,0)) * si.sold_quantity) /
    NULLIF(SUM(si.selling_price * si.sold_quantity),0)) * 100.0 AS avg_margin_pct
FROM Pharmacy_Sale_Item si
LEFT JOIN Purchase_Stock ps
  ON si.batch_no = ps.batch_no AND si.medicine_id = ps.medicine_id
JOIN Medicine m ON si.medicine_id = m.medicine_id
GROUP BY m.medicine_id, m.name
ORDER BY avg_margin_pct DESC NULLS LAST;

-- =====================================================================
-- 6. Revenue by customer_type and payment_mode within a date range
-- =====================================================================
-- Explanation:
-- Group sales by customer_type and payment_mode over a date range and compute gross/gst/discount/net.
-- Use :start_date and :end_date placeholders or replace with explicit dates.
SELECT
  s.customer_type,
  s.payment_mode,
  SUM(si.selling_price * si.sold_quantity) AS gross_revenue,
  SUM(si.discount_amount) AS total_discount,
  SUM(si.selling_price * si.sold_quantity * (COALESCE(m.gst_percentage,0)/100.0)) AS total_gst,
  SUM(si.selling_price * si.sold_quantity) - COALESCE(SUM(si.discount_amount),0)
    + COALESCE(SUM(si.selling_price * si.sold_quantity * (COALESCE(m.gst_percentage,0)/100.0)),0) AS net_revenue
FROM Pharmacy_Sale s
JOIN Pharmacy_Sale_Item si ON s.sale_id = si.sale_id
JOIN Medicine m ON si.medicine_id = m.medicine_id
WHERE s.sale_datetime >= :start_date AND s.sale_datetime <= :end_date
GROUP BY s.customer_type, s.payment_mode
ORDER BY net_revenue DESC;

-- =====================================================================
-- 7. Stock movement summary (opening, purchases, sales, closing) for a period
-- =====================================================================
-- Explanation:
-- Opening stock = purchases_before - sales_before. Then add purchases during and subtract sales during the period.
WITH purchases_before AS (
  SELECT medicine_id, SUM(purchase_quantity) AS purchased_before
  FROM Purchase_Stock
  WHERE purchase_date < :start_date
  GROUP BY medicine_id
),
sales_before AS (
  SELECT si.medicine_id, SUM(si.sold_quantity) AS sold_before
  FROM Pharmacy_Sale_Item si
  JOIN Pharmacy_Sale s ON si.sale_id = s.sale_id
  WHERE s.sale_datetime < :start_date
  GROUP BY si.medicine_id
),
purchases_during AS (
  SELECT medicine_id, SUM(purchase_quantity) AS purchased_during
  FROM Purchase_Stock
  WHERE purchase_date >= :start_date AND purchase_date <= :end_date
  GROUP BY medicine_id
),
sales_during AS (
  SELECT si.medicine_id, SUM(si.sold_quantity) AS sold_during
  FROM Pharmacy_Sale_Item si
  JOIN Pharmacy_Sale s ON si.sale_id = s.sale_id
  WHERE s.sale_datetime >= :start_date AND s.sale_datetime <= :end_date
  GROUP BY si.medicine_id
)
SELECT
  m.medicine_id,
  m.name,
  COALESCE(pb.purchased_before,0) - COALESCE(sb.sold_before,0) AS opening_stock,
  COALESCE(pd.purchased_during,0) AS purchases_during_period,
  COALESCE(sd.sold_during,0) AS sales_during_period,
  (COALESCE(pb.purchased_before,0) - COALESCE(sb.sold_before,0)
    + COALESCE(pd.purchased_during,0) - COALESCE(sd.sold_during,0)) AS closing_stock
FROM Medicine m
LEFT JOIN purchases_before pb ON m.medicine_id = pb.medicine_id
LEFT JOIN sales_before sb ON m.medicine_id = sb.medicine_id
LEFT JOIN purchases_during pd ON m.medicine_id = pd.medicine_id
LEFT JOIN sales_during sd ON m.medicine_id = sd.medicine_id
ORDER BY m.name;

-- =====================================================================
-- 8. High-discount impact: medicines with high avg discount % and their effect
-- =====================================================================
-- Explanation:
-- Compute gross_sales_value, total_discount, avg_discount_pct, total_qty_sold, total_profit and margin_pct.
-- Sort by avg_discount_pct descending to identify items with high discounts and their margins.
WITH med_stats AS (
  SELECT
    si.medicine_id,
    COALESCE(m.name,'UNKNOWN') AS name,
    SUM(si.selling_price * si.sold_quantity) AS gross_sales_value,
    SUM(COALESCE(si.discount_amount,0)) AS total_discount,
    SUM(si.sold_quantity) AS total_qty_sold,
    SUM((si.selling_price - COALESCE(ps.purchase_price,0)) * si.sold_quantity) AS total_profit
  FROM Pharmacy_Sale_Item si
  LEFT JOIN Purchase_Stock ps
    ON si.batch_no = ps.batch_no AND si.medicine_id = ps.medicine_id
  LEFT JOIN Medicine m ON si.medicine_id = m.medicine_id
  GROUP BY si.medicine_id, m.name
)
SELECT
  medicine_id,
  name,
  gross_sales_value,
  total_discount,
  (total_discount / NULLIF(gross_sales_value,0)) * 100.0 AS avg_discount_pct,
  total_qty_sold,
  total_profit,
  (total_profit / NULLIF(gross_sales_value,0)) * 100.0 AS margin_pct
FROM med_stats
WHERE gross_sales_value > 0
ORDER BY avg_discount_pct DESC
LIMIT 20;

-- =====================================================================
-- Helper: Sales items with no matching purchase batch (data issue)
-- =====================================================================
-- Explanation:
-- Identify sale items whose batch_no + medicine_id do not match any record in Purchase_Stock. This helps in deciding fallback pricing rules.
SELECT si.sale_item_id, si.sale_id, si.medicine_id, si.batch_no, si.sold_quantity, si.selling_price
FROM Pharmacy_Sale_Item si
LEFT JOIN Purchase_Stock ps ON si.batch_no = ps.batch_no AND si.medicine_id = ps.medicine_id
WHERE ps.purchase_id IS NULL;

-- =====================================================================
-- Helper: Quick totals cross-check (verify sums)
-- =====================================================================
-- Explanation:
-- Compare total sold units via sale items vs. distinct sale transactions count for a sanity check.
SELECT SUM(sold_quantity) AS total_units_sold FROM Pharmacy_Sale_Item;
SELECT COUNT(*) AS total_sales_txn FROM Pharmacy_Sale;

-- End of file
