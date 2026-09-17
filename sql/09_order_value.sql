-- =============================================================================
-- TAHAP 10 — UNDERSTANDING ORDER VALUE
-- Project: Online Retail Analytics
-- File   : sql/09_order_value.sql
-- =============================================================================
-- Formula: AOV = Basket Size x Average Item Value
--   Basket Size        = Total Quantity / Orders
--   Average Item Value = Revenue / Total Quantity  (harga rata-rata per unit
--                         terjual, weighted by quantity -- BUKAN rata-rata
--                         sederhana across produk)
-- Identity ini EXACT secara aljabar:
--   (TotalQty/Orders) x (Revenue/TotalQty) = Revenue/Orders = AOV
--
-- Semua angka WAJIB reconcile ke total locked KPI Tahap 6.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. IDENTITY CHECK: AOV = Basket Size x Average Item Value (per bulan)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_value_monthly AS
WITH per_order AS (
    SELECT
        fol.invoice,
        MIN(fol.date_key)                          AS date_key,
        SUM(fol.line_revenue)                      AS order_revenue,
        SUM(fol.quantity)                          AS order_quantity,
        COUNT(*)                                   AS n_lines,
        COUNT(DISTINCT fol.product_key)            AS distinct_products
    FROM Fact_Order_Lines fol
    GROUP BY fol.invoice
)
SELECT
    d.year,
    d.month,
    STRFTIME(d.full_date, '%Y-%m')                     AS year_month,
    SUM(po.order_revenue)                              AS revenue,          -- unrounded
    COUNT(*)                                           AS orders,
    SUM(po.order_quantity)                             AS total_quantity,
    SUM(po.order_quantity) * 1.0 / COUNT(*)            AS basket_size,      -- unrounded
    SUM(po.order_revenue) / SUM(po.order_quantity)     AS avg_item_value,   -- unrounded
    SUM(po.order_revenue) / COUNT(*)                   AS aov,              -- unrounded
    AVG(po.n_lines)                                    AS items_per_order,
    AVG(po.distinct_products)                          AS distinct_products_per_order
    -- distinct_products_per_order = rata-rata JUMLAH DISTINCT PRODUK PER
    -- INVOICE (dihitung dulu per order, baru di-AVG) -- bukan
    -- COUNT(DISTINCT product) keseluruhan dibagi orders (itu salah, hasilnya
    -- 0.2 yang tidak masuk akal, sudah diperbaiki di sini).
FROM per_order po
JOIN Dim_Date d ON d.date_key = po.date_key
GROUP BY d.year, d.month, year_month
ORDER BY d.year, d.month;

SELECT
    year_month,
    ROUND(basket_size, 2)                     AS basket_size,
    ROUND(avg_item_value, 4)                  AS avg_item_value,
    ROUND(basket_size * avg_item_value, 2)    AS reconstructed_aov,
    ROUND(aov, 2)                             AS aov,
    (ROUND(basket_size * avg_item_value, 2) = ROUND(aov, 2))  AS identity_holds
FROM v_order_value_monthly
ORDER BY year_month;


-- -----------------------------------------------------------------------------
-- 2. FULL-YEAR COMPARISON: Basket Size vs Average Item Value (2010 vs 2011)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_value_yearly AS
WITH per_order AS (
    SELECT
        fol.invoice,
        MIN(fol.date_key)                          AS date_key,
        SUM(fol.line_revenue)                      AS order_revenue,
        SUM(fol.quantity)                          AS order_quantity,
        COUNT(*)                                   AS n_lines,
        COUNT(DISTINCT fol.product_key)            AS distinct_products
    FROM Fact_Order_Lines fol
    GROUP BY fol.invoice
)
SELECT
    d.year,
    SUM(po.order_revenue)                          AS revenue,
    COUNT(*)                                       AS orders,
    SUM(po.order_quantity)                         AS total_quantity,
    SUM(po.order_quantity) * 1.0 / COUNT(*)        AS basket_size,
    SUM(po.order_revenue) / SUM(po.order_quantity) AS avg_item_value,
    SUM(po.order_revenue) / COUNT(*)               AS aov,
    AVG(po.n_lines)                                AS items_per_order,
    AVG(po.distinct_products)                      AS distinct_products_per_order
FROM per_order po
JOIN Dim_Date d ON d.date_key = po.date_key
WHERE d.year IN (2010, 2011)
GROUP BY d.year;

SELECT
    year, ROUND(revenue,2) AS revenue, orders,
    ROUND(basket_size, 2) AS basket_size,
    ROUND(avg_item_value, 4) AS avg_item_value,
    ROUND(aov, 2) AS aov,
    ROUND(items_per_order, 2) AS items_per_order,
    ROUND(distinct_products_per_order, 2) AS distinct_products_per_order
FROM v_order_value_yearly
ORDER BY year;


-- -----------------------------------------------------------------------------
-- 3. DECOMPOSITION: ΔAOV (2010 → 2011) = Basket Effect + Item Value Effect + Interaction
-- -----------------------------------------------------------------------------
-- Basket Effect     = (Basket_2011 - Basket_2010) x ItemValue_2010
-- Item Value Effect = Basket_2010 x (ItemValue_2011 - ItemValue_2010)
-- Interaction       = (Basket_2011 - Basket_2010) x (ItemValue_2011 - ItemValue_2010)
-- Ketiganya HARUS presis menjumlah ke ΔAOV aktual (exact decomposition).

WITH y AS (
    SELECT
        MAX(CASE WHEN year = 2010 THEN basket_size END)     AS basket_2010,
        MAX(CASE WHEN year = 2011 THEN basket_size END)     AS basket_2011,
        MAX(CASE WHEN year = 2010 THEN avg_item_value END)  AS itemval_2010,
        MAX(CASE WHEN year = 2011 THEN avg_item_value END)  AS itemval_2011,
        MAX(CASE WHEN year = 2010 THEN aov END)             AS aov_2010,
        MAX(CASE WHEN year = 2011 THEN aov END)             AS aov_2011
    FROM v_order_value_yearly
)
SELECT
    ROUND(aov_2010, 2)                                             AS aov_2010,
    ROUND(aov_2011, 2)                                             AS aov_2011,
    ROUND(aov_2011 - aov_2010, 2)                                  AS delta_aov,
    ROUND((basket_2011 - basket_2010) * itemval_2010, 2)           AS basket_effect,
    ROUND(basket_2010 * (itemval_2011 - itemval_2010), 2)          AS item_value_effect,
    ROUND((basket_2011 - basket_2010) * (itemval_2011 - itemval_2010), 2) AS interaction_effect,
    -- sanity check: ketiga efek harus menjumlah ke delta_aov
    ROUND(
        (basket_2011 - basket_2010) * itemval_2010
        + basket_2010 * (itemval_2011 - itemval_2010)
        + (basket_2011 - basket_2010) * (itemval_2011 - itemval_2010)
    , 2)                                                            AS sum_of_effects,
    CASE
        WHEN ABS((basket_2011 - basket_2010) * itemval_2010)
             > ABS(basket_2010 * (itemval_2011 - itemval_2010))
            THEN 'basket-size-driven'
        ELSE 'item-value-driven'
    END                                                              AS dominant_driver
FROM y;


-- -----------------------------------------------------------------------------
-- 4. HIGH-AOV ORDERS: proporsi & karakteristik
-- -----------------------------------------------------------------------------
-- Order dengan AOV di atas P90 keseluruhan (dari EDA Tahap 7: P90 = $879.41)
WITH order_rev AS (
    SELECT
        fol.invoice,
        SUM(fol.line_revenue)                     AS order_revenue,
        SUM(fol.quantity)                         AS order_quantity,
        COUNT(DISTINCT fol.product_key)           AS distinct_products
    FROM Fact_Order_Lines fol
    GROUP BY fol.invoice
)
SELECT
    COUNT(*) FILTER (WHERE order_revenue > 879.41)                          AS high_aov_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE order_revenue > 879.41)
          / COUNT(*), 2)                                                    AS pct_high_aov_orders,
    ROUND(SUM(order_revenue) FILTER (WHERE order_revenue > 879.41), 2)      AS high_aov_revenue,
    ROUND(100.0 * SUM(order_revenue) FILTER (WHERE order_revenue > 879.41)
          / SUM(order_revenue), 2)                                          AS pct_of_total_revenue,
    ROUND(AVG(order_quantity) FILTER (WHERE order_revenue > 879.41), 2)     AS avg_qty_high_aov,
    ROUND(AVG(order_quantity) FILTER (WHERE order_revenue <= 879.41), 2)    AS avg_qty_normal,
    ROUND(AVG(distinct_products) FILTER (WHERE order_revenue > 879.41), 2)  AS avg_distinct_products_high_aov,
    ROUND(AVG(distinct_products) FILTER (WHERE order_revenue <= 879.41), 2) AS avg_distinct_products_normal
FROM order_rev;


-- -----------------------------------------------------------------------------
-- 5. PRODUCT MIX: kontribusi kategori ASP tinggi (furniture, dari temuan EDA outlier)
-- -----------------------------------------------------------------------------
-- StockCode furniture/ASP tinggi teridentifikasi di EDA Tahap 7 Outlier
-- Exploration. Cek apakah share revenue/quantity kategori ini berubah
-- antar tahun -- kandidat penjelas product mix shift.
WITH furniture_flag AS (
    SELECT
        fol.*,
        (p.stock_code IN (
            '22828','22827','22656','21760','22655',
            '22826','22823','21769','22929','84964B'
        )) AS is_high_asp_furniture
    FROM Fact_Order_Lines fol
    JOIN Dim_Product p ON p.product_key = fol.product_key
)
SELECT
    d.year,
    ROUND(SUM(f.line_revenue) FILTER (WHERE f.is_high_asp_furniture), 2)   AS furniture_revenue,
    ROUND(100.0 * SUM(f.line_revenue) FILTER (WHERE f.is_high_asp_furniture)
          / SUM(f.line_revenue), 3)                                        AS pct_of_total_revenue,
    SUM(f.quantity) FILTER (WHERE f.is_high_asp_furniture)                 AS furniture_quantity
FROM furniture_flag f
JOIN Dim_Date d ON d.date_key = f.date_key
WHERE d.year IN (2010, 2011)
GROUP BY d.year
ORDER BY d.year;


-- -----------------------------------------------------------------------------
-- 6. RECONCILIATION CHECK (Acceptance Criteria)
-- -----------------------------------------------------------------------------
SELECT
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)   AS exact_total_revenue,
    19646574.86                                                   AS locked_total_revenue,
    (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines)        AS exact_total_orders,
    41396                                                         AS locked_total_orders,
    (
        (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines) = 19646574.86
        AND (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines) = 41396
    )                                                              AS pass_reconciliation;


-- -----------------------------------------------------------------------------
-- 7. EXPORT (output resmi Tahap 10)
-- -----------------------------------------------------------------------------
COPY (SELECT * FROM v_order_value_monthly)
    TO 'data/processed/09_order_value_monthly.parquet' (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 10
-- =============================================================================
-- [x] Breakdown AOV reconcile ke total locked KPI (Tahap 6)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
