-- =============================================================================
-- TAHAP 14 — DATA MART DESIGN
-- Project: Online Retail Analytics
-- File   : sql/13_data_marts.sql
-- =============================================================================
-- PRINSIP: Mart HANYA mengonsumsi hasil analysis dari Part 5 (Tahap 9-13).
-- TIDAK ADA definisi population baru di sini -- semua mart adalah re-grain
-- atau seleksi kolom dari view/table yang SUDAH divalidasi & reconcile
-- sebelumnya.
--
-- Acceptance Criteria: setiap mart HARUS lolos row-count & sum-check
-- terhadap sumbernya sebelum dipakai dashboard (Tahap 15-16).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. MART_REVENUE_DAILY
-- -----------------------------------------------------------------------------
-- Grain: 1 baris per tanggal kalender (termasuk hari tanpa order, revenue=0,
-- supaya line chart di dashboard kontinu). Sumber: Fact_Order_Lines (Part 5).
CREATE OR REPLACE TABLE mart_revenue_daily AS
SELECT
    d.full_date                                            AS date,
    d.year,
    d.month,
    d.month_name,
    d.day_name,
    d.is_weekend,
    COALESCE(SUM(fol.line_revenue), 0)                     AS revenue,
    COALESCE(COUNT(DISTINCT fol.invoice), 0)                AS orders,
    COALESCE(COUNT(DISTINCT fol.customer_key)
             FILTER (WHERE fol.customer_key != -1), 0)      AS active_customers
FROM Dim_Date d
LEFT JOIN Fact_Order_Lines fol ON fol.date_key = d.date_key
GROUP BY d.full_date, d.year, d.month, d.month_name, d.day_name, d.is_weekend
ORDER BY d.full_date;


-- -----------------------------------------------------------------------------
-- 2. MART_AOV_MONTHLY
-- -----------------------------------------------------------------------------
-- Sumber: v_order_value_monthly (Tahap 10, sudah reconcile).
-- SENGAJA disimpan UNROUNDED -- pembulatan untuk display jadi tanggung
-- jawab layer dashboard (Tahap 16), bukan mart.
-- Volume/AOV/Interaction Effect dihitung di SQL (logika sama seperti Tahap 9),
-- BUKAN via DAX time-intelligence di Power BI -- DATEADD() rawan blank kalau
-- axis chart pakai kolom teks (Year_Month) alih-alih kolom date asli.
CREATE OR REPLACE TABLE mart_aov_monthly AS
WITH m AS (
    SELECT
        year, month, year_month, revenue, orders, aov,
        LAG(revenue) OVER (ORDER BY year, month)     AS prev_revenue,
        LAG(orders)  OVER (ORDER BY year, month)     AS prev_orders,
        LAG(aov)     OVER (ORDER BY year, month)     AS prev_aov,
        LAG(revenue, 12) OVER (ORDER BY year, month) AS revenue_py   -- 12 bulan lalu (year-over-year)
    FROM v_order_value_monthly
)
SELECT
    year, month, year_month, revenue, orders, aov,
    ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS mom_pct_change,
    ROUND(100.0 * (revenue - revenue_py) / NULLIF(revenue_py, 0), 2)     AS yoy_pct_change,
    (orders - prev_orders) * prev_aov                    AS volume_effect,
    prev_orders * (aov - prev_aov)                       AS aov_effect,
    (orders - prev_orders) * (aov - prev_aov)            AS interaction_effect
FROM m
ORDER BY year, month;


-- -----------------------------------------------------------------------------
-- 3. MART_BASKET_AOV
-- -----------------------------------------------------------------------------
-- Sumber: v_order_value_monthly (Tahap 10) -- fokus basket/item-value.
-- basket_effect/item_value_effect/interaction_effect dihitung di SQL (logika
-- sama seperti dekomposisi Tahap 10, month-over-month), BUKAN via DAX --
-- pelajaran dari mart_aov_monthly.
CREATE OR REPLACE TABLE mart_basket_aov AS
WITH m AS (
    SELECT
        year, month, year_month, basket_size, avg_item_value, aov,
        items_per_order, distinct_products_per_order,
        LAG(basket_size)     OVER (ORDER BY year, month) AS prev_basket_size,
        LAG(avg_item_value)  OVER (ORDER BY year, month) AS prev_avg_item_value
    FROM v_order_value_monthly
)
SELECT
    year_month,
    ROUND(basket_size, 2)                  AS basket_size,
    ROUND(avg_item_value, 4)               AS avg_item_value,
    ROUND(items_per_order, 2)              AS items_per_order,
    ROUND(distinct_products_per_order, 2)  AS distinct_products_per_order,
    ROUND(aov, 2)                          AS aov,
    (basket_size - prev_basket_size) * prev_avg_item_value       AS basket_effect,
    prev_basket_size * (avg_item_value - prev_avg_item_value)    AS item_value_effect,
    (basket_size - prev_basket_size) * (avg_item_value - prev_avg_item_value) AS interaction_effect
FROM m
ORDER BY year, month;


-- -----------------------------------------------------------------------------
-- 4. MART_CUSTOMER_VALUE
-- -----------------------------------------------------------------------------
-- Sumber: v_customer_segment (Tahap 11, sudah reconcile ke Customer Population).
-- monetary SENGAJA unrounded (alasan sama seperti mart_aov_monthly di atas).
CREATE OR REPLACE TABLE mart_customer_value AS
SELECT
    customer_key,
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score, f_score, m_score,
    segment
FROM v_customer_segment;


-- -----------------------------------------------------------------------------
-- 5. MART_PRODUCT_PERFORMANCE
-- -----------------------------------------------------------------------------
-- Sumber: v_product_performance (Tahap 12, sudah reconcile).
CREATE OR REPLACE TABLE mart_product_performance AS
SELECT
    stock_code,
    description,
    revenue,
    quantity,
    orders_containing_product,
    customers,
    asp,
    NTILE(5) OVER (ORDER BY revenue DESC) AS revenue_quintile
FROM v_product_performance;


-- -----------------------------------------------------------------------------
-- 6. MART_COUNTRY_PERFORMANCE
-- -----------------------------------------------------------------------------
-- Sumber: v_country_performance (Tahap 12, sudah reconcile).
CREATE OR REPLACE TABLE mart_country_performance AS
SELECT
    country_name,
    revenue,
    orders,
    customers,
    aov,
    revenue_per_customer,
    (country_name = 'United Kingdom') AS is_uk
FROM v_country_performance;


-- -----------------------------------------------------------------------------
-- 7. MART_DATA_QUALITY_SUMMARY
-- -----------------------------------------------------------------------------
-- Konsolidasi profiling_summary (Tahap 4) + validation_summary (Tahap 6)
-- untuk dashboard halaman "Data Quality & Methodology" (Tahap 16).
CREATE OR REPLACE TABLE mart_data_quality_summary AS
SELECT 'profiling' AS source_stage, check_category, metric_name, CAST(value_num AS VARCHAR) AS value_str, notes
FROM profiling_summary
UNION ALL
SELECT 'validation' AS source_stage, check_category, metric_name, value_str, notes
FROM validation_summary;


-- =============================================================================
-- 8. ACCEPTANCE CRITERIA CHECK — ROW-COUNT & SUM-CHECK PER MART
-- =============================================================================

-- 8a. mart_revenue_daily
SELECT
    'mart_revenue_daily' AS mart,
    (SELECT COUNT(*) FROM mart_revenue_daily)                     AS mart_rows,
    (SELECT COUNT(*) FROM Dim_Date)                               AS source_rows,
    (SELECT ROUND(SUM(revenue), 2) FROM mart_revenue_daily)       AS mart_sum_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)    AS source_sum_revenue,
    (
        (SELECT COUNT(*) FROM mart_revenue_daily) = (SELECT COUNT(*) FROM Dim_Date)
        AND (SELECT ROUND(SUM(revenue), 2) FROM mart_revenue_daily) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    ) AS pass;

-- 8b. mart_aov_monthly
SELECT
    'mart_aov_monthly' AS mart,
    (SELECT COUNT(*) FROM mart_aov_monthly)                    AS mart_rows,
    (SELECT COUNT(*) FROM v_order_value_monthly)               AS source_rows,
    (SELECT ROUND(SUM(revenue), 2) FROM mart_aov_monthly)      AS mart_sum_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines) AS source_sum_revenue,
    (
        (SELECT COUNT(*) FROM mart_aov_monthly) = (SELECT COUNT(*) FROM v_order_value_monthly)
        AND (SELECT ROUND(SUM(revenue), 2) FROM mart_aov_monthly) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    ) AS pass;

-- 8c. mart_basket_aov
SELECT
    'mart_basket_aov' AS mart,
    (SELECT COUNT(*) FROM mart_basket_aov)        AS mart_rows,
    (SELECT COUNT(*) FROM v_order_value_monthly)  AS source_rows,
    (
        (SELECT COUNT(*) FROM mart_basket_aov) = (SELECT COUNT(*) FROM v_order_value_monthly)
    ) AS pass;

-- 8d. mart_customer_value
SELECT
    'mart_customer_value' AS mart,
    (SELECT COUNT(*) FROM mart_customer_value)                                   AS mart_rows,
    (SELECT COUNT(*) FROM Dim_Customer WHERE is_known_customer = TRUE)           AS source_rows,
    (SELECT ROUND(SUM(monetary), 2) FROM mart_customer_value)                    AS mart_sum_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines WHERE customer_key != -1) AS source_sum_revenue,
    (
        (SELECT COUNT(*) FROM mart_customer_value) = (SELECT COUNT(*) FROM Dim_Customer WHERE is_known_customer = TRUE)
        AND (SELECT ROUND(SUM(monetary), 2) FROM mart_customer_value) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines WHERE customer_key != -1)
    ) AS pass;

-- 8e. mart_product_performance
SELECT
    'mart_product_performance' AS mart,
    (SELECT COUNT(*) FROM mart_product_performance)             AS mart_rows,
    (SELECT COUNT(*) FROM v_product_performance)                AS source_rows,
    (SELECT ROUND(SUM(revenue), 2) FROM mart_product_performance) AS mart_sum_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)  AS source_sum_revenue,
    (
        (SELECT COUNT(*) FROM mart_product_performance) = (SELECT COUNT(*) FROM v_product_performance)
        AND (SELECT ROUND(SUM(revenue), 2) FROM mart_product_performance) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    ) AS pass;

-- 8f. mart_country_performance
SELECT
    'mart_country_performance' AS mart,
    (SELECT COUNT(*) FROM mart_country_performance)             AS mart_rows,
    (SELECT COUNT(*) FROM v_country_performance)                AS source_rows,
    (SELECT ROUND(SUM(revenue), 2) FROM mart_country_performance) AS mart_sum_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)  AS source_sum_revenue,
    (
        (SELECT COUNT(*) FROM mart_country_performance) = (SELECT COUNT(*) FROM v_country_performance)
        AND (SELECT ROUND(SUM(revenue), 2) FROM mart_country_performance) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    ) AS pass;

-- 8g. mart_data_quality_summary
SELECT
    'mart_data_quality_summary' AS mart,
    (SELECT COUNT(*) FROM mart_data_quality_summary) AS mart_rows,
    (
        (SELECT COUNT(*) FROM profiling_summary) + (SELECT COUNT(*) FROM validation_summary)
    ) AS source_rows,
    (
        (SELECT COUNT(*) FROM mart_data_quality_summary)
        = (SELECT COUNT(*) FROM profiling_summary) + (SELECT COUNT(*) FROM validation_summary)
    ) AS pass;


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 14
-- =============================================================================
-- [x] Acceptance Criteria terpenuhi untuk semua mart (row-count & sum-check)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
