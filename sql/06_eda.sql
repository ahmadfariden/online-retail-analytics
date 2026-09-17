-- =============================================================================
-- TAHAP 7 — EXPLORATORY DATA ANALYSIS (EDA)
-- Project: Online Retail Analytics
-- File   : sql/06_eda.sql
-- =============================================================================
-- Tujuan: memahami pola utama dataset setelah data dibersihkan & divalidasi.
-- BUKAN membuat dashboard, BUKAN mengubah KPI/population.
--
-- EDA Governance (WAJIB dipatuhi):
--   - EDA TIDAK mengubah definisi KPI (locked di Tahap 6)
--   - EDA TIDAK mengubah analytical population
--   - EDA TIDAK menghapus data tanpa justifikasi
--   - EDA TIDAK membuat kesimpulan kausal (observasional saja)
--   Kalau ditemukan masalah data baru -> kembali ke Tahap 5 -> Tahap 6 ->
--   ulangi EDA. JANGAN diubah langsung di sini.
--
-- Semua query di bawah menggunakan v_revenue_population / v_customer_population
-- (locked di Tahap 6), BUKAN raw_online_retail.
-- =============================================================================


-- =============================================================================
-- 1. REVENUE EXPLORATION
-- =============================================================================

-- 1a. Revenue distribution (per order)
WITH order_rev AS (
    SELECT Invoice, SUM(Quantity * Price) AS order_revenue
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT
    MIN(order_revenue)                     AS min_order_revenue,
    approx_quantile(order_revenue, 0.25)   AS p25,
    approx_quantile(order_revenue, 0.50)   AS median,
    approx_quantile(order_revenue, 0.75)   AS p75,
    approx_quantile(order_revenue, 0.90)   AS p90,
    approx_quantile(order_revenue, 0.99)   AS p99,
    MAX(order_revenue)                     AS max_order_revenue
FROM order_rev;

-- 1b. Revenue by month
SELECT
    DATE_TRUNC('month', InvoiceDate) AS month,
    ROUND(SUM(Quantity * Price), 2)  AS revenue,
    COUNT(DISTINCT Invoice)          AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;

-- 1c. Revenue by quarter
SELECT
    DATE_TRUNC('quarter', InvoiceDate) AS quarter,
    ROUND(SUM(Quantity * Price), 2)    AS revenue,
    COUNT(DISTINCT Invoice)            AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;

-- 1d. Revenue concentration (Pareto check by Invoice)
WITH order_rev AS (
    SELECT Invoice, SUM(Quantity * Price) AS order_revenue
    FROM v_revenue_population
    GROUP BY Invoice
),
ranked AS (
    SELECT
        Invoice, order_revenue,
        NTILE(5) OVER (ORDER BY order_revenue DESC) AS revenue_quintile
    FROM order_rev
)
SELECT
    revenue_quintile,
    COUNT(*)                                                    AS n_orders,
    ROUND(SUM(order_revenue), 2)                                AS revenue,
    ROUND(100.0 * SUM(order_revenue) / SUM(SUM(order_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM ranked
GROUP BY revenue_quintile
ORDER BY revenue_quintile;

-- 1e. Revenue trend (month-over-month growth %)
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', InvoiceDate) AS month,
        SUM(Quantity * Price)            AS revenue
    FROM v_revenue_population
    GROUP BY 1
)
SELECT
    month,
    ROUND(revenue, 2)                                                    AS revenue,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2)               AS mom_change,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2)            AS mom_pct_change
FROM monthly
ORDER BY month;


-- =============================================================================
-- 2. ORDER EXPLORATION
-- =============================================================================

-- 2a. Order distribution per month
SELECT
    DATE_TRUNC('month', InvoiceDate) AS month,
    COUNT(DISTINCT Invoice)          AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;

-- 2b. Order revenue distribution (lihat 1a, sama)

-- 2c. Basket size distribution (quantity per order)
WITH basket AS (
    SELECT Invoice, SUM(Quantity) AS total_qty
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT
    MIN(total_qty)                   AS min_qty,
    approx_quantile(total_qty, 0.25) AS p25,
    approx_quantile(total_qty, 0.50) AS median,
    approx_quantile(total_qty, 0.75) AS p75,
    approx_quantile(total_qty, 0.99) AS p99,
    MAX(total_qty)                   AS max_qty
FROM basket;

-- 2d. Items per order (distinct product lines per order)
WITH items AS (
    SELECT Invoice, COUNT(DISTINCT StockCode) AS distinct_items
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT
    MIN(distinct_items)                   AS min_items,
    approx_quantile(distinct_items, 0.50) AS median_items,
    approx_quantile(distinct_items, 0.90) AS p90_items,
    MAX(distinct_items)                   AS max_items,
    ROUND(AVG(distinct_items), 2)         AS avg_items
FROM items;


-- =============================================================================
-- 3. AOV EXPLORATION
-- =============================================================================

WITH order_rev AS (
    SELECT Invoice, SUM(Quantity * Price) AS order_revenue
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT
    ROUND(AVG(order_revenue), 2)             AS aov_mean,
    ROUND(approx_quantile(order_revenue, 0.50), 2) AS aov_median,
    ROUND(approx_quantile(order_revenue, 0.25), 2) AS p25,
    ROUND(approx_quantile(order_revenue, 0.75), 2) AS p75,
    ROUND(approx_quantile(order_revenue, 0.90), 2) AS p90,
    ROUND(approx_quantile(order_revenue, 0.95), 2) AS p95,
    ROUND(approx_quantile(order_revenue, 0.99), 2) AS p99,
    ROUND(STDDEV(order_revenue), 2)          AS stddev,
    -- skewness sederhana: (mean - median) / stddev, indikator arah skew
    ROUND((AVG(order_revenue) - approx_quantile(order_revenue, 0.50))
          / NULLIF(STDDEV(order_revenue), 0), 4)               AS skew_indicator
FROM order_rev;

-- High-AOV orders (top 20)
WITH order_rev AS (
    SELECT Invoice, SUM(Quantity * Price) AS order_revenue,
           ANY_VALUE(Country) AS country
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT Invoice, ROUND(order_revenue, 2) AS order_revenue, country
FROM order_rev
ORDER BY order_revenue DESC
LIMIT 20;


-- =============================================================================
-- 4. CUSTOMER EXPLORATION
-- =============================================================================

-- 4a. Customer distribution (revenue per customer)
WITH customer_rev AS (
    SELECT customer_id, SUM(Quantity * Price) AS customer_revenue
    FROM v_customer_population
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                    AS n_customers,
    MIN(customer_revenue)                       AS min_rev,
    approx_quantile(customer_revenue, 0.50)     AS median_rev,
    approx_quantile(customer_revenue, 0.90)     AS p90_rev,
    approx_quantile(customer_revenue, 0.99)     AS p99_rev,
    MAX(customer_revenue)                       AS max_rev
FROM customer_rev;

-- 4b. Order frequency per customer
WITH cust_orders AS (
    SELECT customer_id, COUNT(DISTINCT Invoice) AS n_orders
    FROM v_customer_population
    GROUP BY customer_id
)
SELECT
    ROUND(AVG(n_orders), 2)                AS avg_orders_per_customer,
    approx_quantile(n_orders, 0.50)        AS median_orders_per_customer,
    MAX(n_orders)                          AS max_orders_per_customer
FROM cust_orders;

-- 4c. One-time vs repeat customers
WITH cust_orders AS (
    SELECT customer_id, COUNT(DISTINCT Invoice) AS n_orders
    FROM v_customer_population
    GROUP BY customer_id
)
SELECT
    COUNT(*) FILTER (WHERE n_orders = 1)                          AS one_time_customers,
    COUNT(*) FILTER (WHERE n_orders > 1)                          AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_orders = 1) / COUNT(*), 2) AS pct_one_time,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_orders > 1) / COUNT(*), 2) AS pct_repeat
FROM cust_orders;

-- 4d. Customer revenue concentration (Pareto: top 20% customer -> % revenue)
WITH customer_rev AS (
    SELECT customer_id, SUM(Quantity * Price) AS customer_revenue
    FROM v_customer_population
    GROUP BY customer_id
),
ranked AS (
    SELECT
        customer_id, customer_revenue,
        NTILE(5) OVER (ORDER BY customer_revenue DESC) AS revenue_quintile
    FROM customer_rev
)
SELECT
    revenue_quintile,
    COUNT(*)                                                     AS n_customers,
    ROUND(SUM(customer_revenue), 2)                              AS revenue,
    ROUND(100.0 * SUM(customer_revenue) / SUM(SUM(customer_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM ranked
GROUP BY revenue_quintile
ORDER BY revenue_quintile;


-- =============================================================================
-- 5. PRODUCT EXPLORATION
-- =============================================================================

-- 5a. Product distribution (revenue per StockCode)
WITH product_rev AS (
    SELECT StockCode, ANY_VALUE(Description) AS description,
           SUM(Quantity * Price) AS product_revenue,
           SUM(Quantity)          AS product_qty
    FROM v_revenue_population
    GROUP BY StockCode
)
SELECT
    COUNT(*)                                   AS n_products,
    approx_quantile(product_revenue, 0.50)     AS median_product_revenue,
    approx_quantile(product_revenue, 0.90)     AS p90_product_revenue,
    MAX(product_revenue)                       AS max_product_revenue
FROM product_rev;

-- 5b. Product revenue concentration + long-tail (top 20 products)
WITH product_rev AS (
    SELECT StockCode, ANY_VALUE(Description) AS description,
           SUM(Quantity * Price) AS product_revenue
    FROM v_revenue_population
    GROUP BY StockCode
)
SELECT StockCode, description, ROUND(product_revenue, 2) AS product_revenue,
       ROUND(100.0 * product_revenue / SUM(product_revenue) OVER (), 3) AS pct_of_total_revenue
FROM product_rev
ORDER BY product_revenue DESC
LIMIT 20;

-- 5c. Product volume distribution + long-tail summary (quintile)
WITH product_rev AS (
    SELECT StockCode, SUM(Quantity * Price) AS product_revenue
    FROM v_revenue_population
    GROUP BY StockCode
),
ranked AS (
    SELECT StockCode, product_revenue,
           NTILE(5) OVER (ORDER BY product_revenue DESC) AS revenue_quintile
    FROM product_rev
)
SELECT
    revenue_quintile,
    COUNT(*)                                                     AS n_products,
    ROUND(SUM(product_revenue), 2)                               AS revenue,
    ROUND(100.0 * SUM(product_revenue) / SUM(SUM(product_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM ranked
GROUP BY revenue_quintile
ORDER BY revenue_quintile;


-- =============================================================================
-- 6. COUNTRY EXPLORATION
-- =============================================================================

SELECT
    Country,
    ROUND(SUM(Quantity * Price), 2)         AS revenue,
    COUNT(DISTINCT Invoice)                  AS orders,
    COUNT(DISTINCT customer_id)              AS customers,
    ROUND(SUM(Quantity * Price)
          / COUNT(DISTINCT Invoice), 2)      AS aov,
    ROUND(100.0 * SUM(Quantity * Price)
          / SUM(SUM(Quantity * Price)) OVER (), 2) AS pct_of_total_revenue
FROM v_revenue_population
GROUP BY Country
ORDER BY revenue DESC;

-- Small-market behavior: bandingkan AOV UK vs non-UK
SELECT
    CASE WHEN Country = 'United Kingdom' THEN 'UK' ELSE 'Non-UK' END AS market,
    ROUND(SUM(Quantity * Price), 2)                    AS revenue,
    COUNT(DISTINCT Invoice)                            AS orders,
    ROUND(SUM(Quantity * Price) / COUNT(DISTINCT Invoice), 2) AS aov
FROM v_revenue_population
GROUP BY 1;


-- =============================================================================
-- 7. TIME EXPLORATION
-- =============================================================================

-- 7a. Monthly pattern (across all years combined, cari seasonality)
SELECT
    MONTH(InvoiceDate)                AS month_num,
    ROUND(SUM(Quantity * Price), 2)   AS revenue,
    COUNT(DISTINCT Invoice)           AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;

-- 7b. Quarterly pattern
SELECT
    QUARTER(InvoiceDate)              AS quarter_num,
    ROUND(SUM(Quantity * Price), 2)   AS revenue,
    COUNT(DISTINCT Invoice)           AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;

-- 7c. Day-of-week pattern
SELECT
    DAYNAME(InvoiceDate)              AS day_of_week,
    DAYOFWEEK(InvoiceDate)            AS day_num,
    ROUND(SUM(Quantity * Price), 2)   AS revenue,
    COUNT(DISTINCT Invoice)           AS orders
FROM v_revenue_population
GROUP BY 1, 2
ORDER BY 2;

-- 7d. Hour-of-day pattern
SELECT
    HOUR(InvoiceDate)                 AS hour_of_day,
    ROUND(SUM(Quantity * Price), 2)   AS revenue,
    COUNT(DISTINCT Invoice)           AS orders
FROM v_revenue_population
GROUP BY 1
ORDER BY 1;


-- =============================================================================
-- 8. OUTLIER EXPLORATION
-- =============================================================================

-- 8a. High-value orders (top 10) -- lihat juga Section 3 (High-AOV orders)

-- 8b. Extreme quantity per line (top 10, dari populasi valid, bukan raw)
SELECT Invoice, StockCode, Description, Quantity, Price, customer_id, Country
FROM v_revenue_population
ORDER BY Quantity DESC
LIMIT 10;

-- 8c. Extreme price / ASP per produk (top 10 average selling price)
WITH product_asp AS (
    SELECT StockCode, ANY_VALUE(Description) AS description,
           ROUND(SUM(Quantity * Price) / NULLIF(SUM(Quantity), 0), 2) AS asp,
           SUM(Quantity) AS total_qty
    FROM v_revenue_population
    GROUP BY StockCode
    HAVING SUM(Quantity) > 10  -- exclude produk dengan volume terlalu kecil biar ASP tidak noise
)
SELECT * FROM product_asp
ORDER BY asp DESC
LIMIT 10;

-- 8d. Extreme customer value (top 10 customer by revenue)
WITH customer_rev AS (
    SELECT customer_id, ANY_VALUE(Country) AS country,
           SUM(Quantity * Price) AS customer_revenue,
           COUNT(DISTINCT Invoice) AS n_orders
    FROM v_customer_population
    GROUP BY customer_id
)
SELECT * FROM customer_rev
ORDER BY customer_revenue DESC
LIMIT 10;


-- =============================================================================
-- ACCEPTANCE CRITERIA CHECK
-- =============================================================================
-- Semua 8 kategori exploration di atas harus menghasilkan MINIMAL:
--   1 finding (angka/pola konkret) + 1 hipotesis kandidat untuk business
--   analysis (Part 5). Isi hipotesis di docs/eda_findings.md setelah hasil
--   query dikirim balik dan didiskusikan.
-- =============================================================================


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 7
-- =============================================================================
-- [x] Acceptance Criteria terpenuhi (8 kategori x minimal 1 finding + 1 hipotesis)
-- [x] Output tersimpan di path yang benar (docs/eda_findings.md)
-- [x] Tidak ada perubahan diam-diam ke KPI/population (lihat EDA Governance)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
