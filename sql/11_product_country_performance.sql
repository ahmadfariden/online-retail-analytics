-- =============================================================================
-- TAHAP 12 — PRODUCT & COUNTRY PERFORMANCE
-- Project: Online Retail Analytics
-- File   : sql/11_product_country_performance.sql
-- =============================================================================
-- Semua angka WAJIB reconcile ke total locked KPI Tahap 6.
-- =============================================================================


-- =============================================================================
-- PART A — PRODUCT PERFORMANCE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A1. Product Summary: Revenue, Quantity, Orders, Customers, ASP
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
    p.stock_code,
    p.description,
    SUM(fol.line_revenue)                                          AS revenue,
    SUM(fol.quantity)                                              AS quantity,
    COUNT(DISTINCT fol.invoice)                                    AS orders_containing_product,
    COUNT(DISTINCT fol.customer_key) FILTER (WHERE fol.customer_key != -1) AS customers,
    SUM(fol.line_revenue) / SUM(fol.quantity)                      AS asp
FROM Fact_Order_Lines fol
JOIN Dim_Product p ON p.product_key = fol.product_key
GROUP BY p.stock_code, p.description;

-- Top 20 produk by revenue
SELECT
    stock_code, description,
    ROUND(revenue, 2)                    AS revenue,
    quantity, orders_containing_product, customers,
    ROUND(asp, 2)                        AS asp,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 3) AS pct_of_total_revenue
FROM v_product_performance
ORDER BY revenue DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- A2. Product Concentration (quintile)
-- -----------------------------------------------------------------------------
WITH ranked AS (
    SELECT stock_code, revenue,
           NTILE(5) OVER (ORDER BY revenue DESC) AS revenue_quintile
    FROM v_product_performance
)
SELECT
    revenue_quintile,
    COUNT(*)                                                     AS n_products,
    ROUND(SUM(revenue), 2)                                       AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2)  AS pct_of_total_revenue
FROM ranked
GROUP BY revenue_quintile
ORDER BY revenue_quintile;


-- -----------------------------------------------------------------------------
-- A3. High-AOV Product Presence
-- -----------------------------------------------------------------------------
-- Untuk tiap produk: berapa % dari order yang mengandung produk ini yang
-- tergolong high-AOV (>P90 = $879.41, threshold locked di Tahap 10).
WITH order_class AS (
    SELECT
        invoice,
        SUM(line_revenue) AS order_revenue
    FROM Fact_Order_Lines
    GROUP BY invoice
),
product_order AS (
    SELECT DISTINCT fol.invoice, p.stock_code
    FROM Fact_Order_Lines fol
    JOIN Dim_Product p ON p.product_key = fol.product_key
)
SELECT
    po.stock_code,
    COUNT(*)                                                              AS total_orders,
    COUNT(*) FILTER (WHERE oc.order_revenue > 879.41)                     AS high_aov_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE oc.order_revenue > 879.41)
          / COUNT(*), 2)                                                  AS pct_high_aov_presence
FROM product_order po
JOIN order_class oc ON oc.invoice = po.invoice
GROUP BY po.stock_code
HAVING COUNT(*) >= 30   -- exclude produk dengan sample order terlalu kecil
ORDER BY pct_high_aov_presence DESC
LIMIT 15;


-- -----------------------------------------------------------------------------
-- A4. Reconciliation Product
-- -----------------------------------------------------------------------------
SELECT
    (SELECT ROUND(SUM(revenue), 2) FROM v_product_performance)   AS sum_product_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)   AS locked_total_revenue,
    (
        (SELECT ROUND(SUM(revenue), 2) FROM v_product_performance)
        = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    )                                                              AS pass_product_reconciliation;


-- =============================================================================
-- PART B — COUNTRY PERFORMANCE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- B1. Country Summary: Revenue, Orders, Customers, AOV
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_country_performance AS
SELECT
    co.country_name,
    SUM(fol.line_revenue)                                          AS revenue,
    COUNT(DISTINCT fol.invoice)                                    AS orders,
    COUNT(DISTINCT fol.customer_key) FILTER (WHERE fol.customer_key != -1) AS customers,
    SUM(fol.line_revenue) / COUNT(DISTINCT fol.invoice)            AS aov,
    SUM(fol.line_revenue)
        / NULLIF(COUNT(DISTINCT fol.customer_key) FILTER (WHERE fol.customer_key != -1), 0) AS revenue_per_customer
FROM Fact_Order_Lines fol
JOIN Dim_Country co ON co.country_key = fol.country_key
GROUP BY co.country_name;

SELECT
    country_name,
    ROUND(revenue, 2)                                    AS revenue,
    orders,
    customers,
    ROUND(aov, 2)                                        AS aov,
    ROUND(revenue_per_customer, 2)                       AS revenue_per_customer,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)     AS pct_of_total_revenue,
    ROUND(100.0 * orders / SUM(orders) OVER (), 2)       AS pct_of_total_orders
FROM v_country_performance
ORDER BY revenue DESC;


-- -----------------------------------------------------------------------------
-- B2. Absolute vs Relative Performance (UK vs Non-UK, sudah dari EDA, recompute)
-- -----------------------------------------------------------------------------
SELECT
    CASE WHEN country_name = 'United Kingdom' THEN 'UK' ELSE 'Non-UK' END AS market,
    ROUND(SUM(revenue), 2)                              AS revenue,
    SUM(orders)                                          AS orders,
    SUM(customers)                                       AS customers,
    ROUND(SUM(revenue) / SUM(orders), 2)                AS aov,
    ROUND(SUM(revenue) / NULLIF(SUM(customers), 0), 2)  AS revenue_per_customer
FROM v_country_performance
GROUP BY 1;


-- -----------------------------------------------------------------------------
-- B3. Volume vs AOV Matrix (kuadran, threshold median dari seluruh negara)
-- -----------------------------------------------------------------------------
WITH stats AS (
    SELECT
        MEDIAN(orders) AS median_orders,
        MEDIAN(aov)    AS median_aov
    FROM v_country_performance
)
SELECT
    cp.country_name,
    cp.orders,
    ROUND(cp.aov, 2) AS aov,
    CASE
        WHEN cp.orders >= s.median_orders AND cp.aov >= s.median_aov THEN 'High Volume, High AOV'
        WHEN cp.orders >= s.median_orders AND cp.aov <  s.median_aov THEN 'High Volume, Low AOV'
        WHEN cp.orders <  s.median_orders AND cp.aov >= s.median_aov THEN 'Low Volume, High AOV'
        ELSE 'Low Volume, Low AOV'
    END AS quadrant
FROM v_country_performance cp, stats s
ORDER BY cp.orders DESC;


-- -----------------------------------------------------------------------------
-- B4. Reconciliation Country
-- -----------------------------------------------------------------------------
SELECT
    (SELECT ROUND(SUM(revenue), 2) FROM v_country_performance)   AS sum_country_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)   AS locked_total_revenue,
    (SELECT SUM(orders) FROM v_country_performance)               AS sum_country_orders,
    (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines)        AS locked_total_orders,
    (
        (SELECT ROUND(SUM(revenue), 2) FROM v_country_performance) = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
        AND (SELECT SUM(orders) FROM v_country_performance) = (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines)
    )                                                              AS pass_country_reconciliation;


-- =============================================================================
-- PART C — CROSS-CHECK: Champions Segment x Country (uji hipotesis Tahap 11)
-- =============================================================================
SELECT
    dc.primary_country,
    cs.segment,
    COUNT(*)                                     AS n_customers,
    ROUND(SUM(cs.monetary), 2)                   AS segment_country_revenue
FROM v_customer_segment cs
JOIN Dim_Customer dc ON dc.customer_key = cs.customer_key
WHERE cs.segment = 'Champions'
GROUP BY dc.primary_country, cs.segment
ORDER BY segment_country_revenue DESC
LIMIT 15;


-- -----------------------------------------------------------------------------
-- EXPORT (output resmi Tahap 12)
-- -----------------------------------------------------------------------------
COPY (SELECT * FROM v_product_performance) TO 'data/processed/11_product_performance.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM v_country_performance) TO 'data/processed/11_country_performance.parquet' (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 12
-- =============================================================================
-- [x] Breakdown product & country reconcile ke total locked KPI (Tahap 6)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
