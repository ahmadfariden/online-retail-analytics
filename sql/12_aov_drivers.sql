-- =============================================================================
-- TAHAP 13 — AOV DRIVERS & REVENUE DECOMPOSITION
-- Project: Online Retail Analytics
-- File   : sql/12_aov_drivers.sql
-- =============================================================================
-- ⚠️ CAUSAL INTERPRETATION BOUNDARIES (WAJIB DIPATUHI):
-- Seluruh analisis di file ini BERSIFAT OBSERVASIONAL. Tujuannya menjelaskan
-- what/where/who/what-is-associated, BUKAN membuktikan causality, uplift,
-- atau business impact certainty.
--   Gunakan   : "associated with", "correlated with", "tends to occur with"
--   HINDARI   : "caused by", "resulted in", "led to", "proved that"
-- Aturan ini berlaku untuk SEMUA komentar SQL, alias kolom, dan narasi di
-- docs/aov_drivers_findings.md.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. ORDER-LEVEL BASE TABLE (dengan semua dimensi kandidat)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_dimensions AS
WITH order_base AS (
    SELECT
        fol.invoice,
        ANY_VALUE(fol.customer_key)                AS customer_key,
        ANY_VALUE(fol.country_key)                 AS country_key,
        ANY_VALUE(fol.date_key)                    AS date_key,
        SUM(fol.line_revenue)                      AS order_revenue,
        SUM(fol.quantity)                          AS order_quantity,
        COUNT(DISTINCT fol.product_key)            AS distinct_products
    FROM Fact_Order_Lines fol
    GROUP BY fol.invoice
)
SELECT
    ob.invoice,
    ob.order_revenue,
    ob.order_quantity,
    ob.distinct_products,
    co.country_name,
    (co.country_name = 'United Kingdom')           AS is_uk,
    d.year_month,
    d.month,
    ob.customer_key,
    cs.segment,
    cs.frequency                                    AS customer_frequency
FROM order_base ob
JOIN Dim_Country co ON co.country_key = ob.country_key
JOIN (SELECT date_key, STRFTIME(full_date,'%Y-%m') AS year_month, month FROM Dim_Date) d
     ON d.date_key = ob.date_key
LEFT JOIN v_customer_segment cs ON cs.customer_key = ob.customer_key;


-- -----------------------------------------------------------------------------
-- 1. GROUPED COMPARISON: AOV by Customer Segment
-- -----------------------------------------------------------------------------
-- Hanya order dari customer dengan segment valid (customer_key != -1).
SELECT
    segment,
    COUNT(*)                                        AS n_orders,
    ROUND(AVG(order_revenue), 2)                    AS aov_mean,
    ROUND(MEDIAN(order_revenue), 2)                 AS aov_median,
    ROUND(approx_quantile(order_revenue, 0.90), 2)  AS aov_p90,
    ROUND(STDDEV(order_revenue), 2)                 AS aov_stddev
FROM v_order_dimensions
WHERE segment IS NOT NULL
GROUP BY segment
ORDER BY aov_mean DESC;


-- -----------------------------------------------------------------------------
-- 2. GROUPED COMPARISON: AOV by Country (UK vs Non-UK, distribusi lengkap)
-- -----------------------------------------------------------------------------
SELECT
    CASE WHEN is_uk THEN 'UK' ELSE 'Non-UK' END AS market,
    COUNT(*)                                        AS n_orders,
    ROUND(AVG(order_revenue), 2)                    AS aov_mean,
    ROUND(MEDIAN(order_revenue), 2)                 AS aov_median,
    ROUND(approx_quantile(order_revenue, 0.90), 2)  AS aov_p90,
    ROUND(STDDEV(order_revenue), 2)                 AS aov_stddev
FROM v_order_dimensions
GROUP BY 1;


-- -----------------------------------------------------------------------------
-- 3. GROUPED COMPARISON: AOV by Month (ringkasan, detail lengkap di Tahap 9)
-- -----------------------------------------------------------------------------
SELECT
    year_month,
    COUNT(*)                          AS n_orders,
    ROUND(AVG(order_revenue), 2)      AS aov_mean,
    ROUND(MEDIAN(order_revenue), 2)   AS aov_median
FROM v_order_dimensions
GROUP BY year_month
ORDER BY year_month;


-- -----------------------------------------------------------------------------
-- 4. CORRELATION: Order Revenue vs Basket Size & Product Diversity
-- -----------------------------------------------------------------------------
-- Interpretasi: korelasi menunjukkan asosiasi linear, BUKAN hubungan sebab-akibat.
SELECT
    ROUND(CORR(order_revenue, order_quantity), 4)     AS corr_revenue_quantity,
    ROUND(CORR(order_revenue, distinct_products), 4)  AS corr_revenue_distinct_products,
    ROUND(CORR(order_quantity, distinct_products), 4) AS corr_quantity_distinct_products
FROM v_order_dimensions;


-- -----------------------------------------------------------------------------
-- 5. CORRELATION: Purchase Frequency vs Average Order Value (level customer)
-- -----------------------------------------------------------------------------
WITH customer_level AS (
    SELECT
        customer_key,
        customer_frequency,
        AVG(order_revenue) AS avg_order_value
    FROM v_order_dimensions
    WHERE segment IS NOT NULL
    GROUP BY customer_key, customer_frequency
)
SELECT
    ROUND(CORR(customer_frequency, avg_order_value), 4) AS corr_frequency_vs_aov,
    COUNT(*)                                             AS n_customers
FROM customer_level;


-- -----------------------------------------------------------------------------
-- 6. CONTRIBUTION ANALYSIS: Eta-Squared (proporsi variasi order revenue yang
--    "berasosiasi" dengan tiap dimensi -- deskriptif, BUKAN causal)
-- -----------------------------------------------------------------------------
-- Eta-squared = SS_between / SS_total. Interpretasi: seberapa besar variasi
-- order_revenue yang ASOSIASINYA searah dengan dimensi tsb (bukan "dijelaskan
-- secara kausal oleh").

-- 6a. by Customer Segment
WITH grand AS (
    SELECT AVG(order_revenue) AS grand_mean, VAR_POP(order_revenue) * COUNT(*) AS ss_total, COUNT(*) AS n
    FROM v_order_dimensions WHERE segment IS NOT NULL
),
grp AS (
    SELECT segment, COUNT(*) AS n_g, AVG(order_revenue) AS mean_g
    FROM v_order_dimensions WHERE segment IS NOT NULL
    GROUP BY segment
)
SELECT
    'Customer Segment' AS dimension,
    ROUND(SUM(g.n_g * POW(g.mean_g - gr.grand_mean, 2)) / gr.ss_total, 4) AS eta_squared
FROM grp g, grand gr
GROUP BY gr.ss_total

UNION ALL

-- 6b. by Country (UK vs Non-UK)
SELECT
    'Country (UK vs Non-UK)',
    ROUND(SUM(g.n_g * POW(g.mean_g - gr.grand_mean, 2)) / gr.ss_total, 4)
FROM (
    SELECT is_uk, COUNT(*) AS n_g, AVG(order_revenue) AS mean_g
    FROM v_order_dimensions GROUP BY is_uk
) g,
(
    SELECT AVG(order_revenue) AS grand_mean, VAR_POP(order_revenue) * COUNT(*) AS ss_total
    FROM v_order_dimensions
) gr
GROUP BY gr.ss_total, gr.grand_mean

UNION ALL

-- 6c. by Month
SELECT
    'Month',
    ROUND(SUM(g.n_g * POW(g.mean_g - gr.grand_mean, 2)) / gr.ss_total, 4)
FROM (
    SELECT year_month, COUNT(*) AS n_g, AVG(order_revenue) AS mean_g
    FROM v_order_dimensions GROUP BY year_month
) g,
(
    SELECT AVG(order_revenue) AS grand_mean, VAR_POP(order_revenue) * COUNT(*) AS ss_total
    FROM v_order_dimensions
) gr
GROUP BY gr.ss_total, gr.grand_mean

ORDER BY eta_squared DESC;


-- -----------------------------------------------------------------------------
-- 7. RECONCILIATION CHECK (Acceptance Criteria)
-- -----------------------------------------------------------------------------
SELECT
    (SELECT ROUND(SUM(order_revenue), 2) FROM v_order_dimensions)  AS exact_total_revenue,
    19646574.86                                                     AS locked_total_revenue,
    (SELECT COUNT(*) FROM v_order_dimensions)                       AS exact_total_orders,
    41396                                                            AS locked_total_orders,
    (
        (SELECT ROUND(SUM(order_revenue), 2) FROM v_order_dimensions) = 19646574.86
        AND (SELECT COUNT(*) FROM v_order_dimensions) = 41396
    )                                                                AS pass_reconciliation;


-- -----------------------------------------------------------------------------
-- 8. EXPORT (output resmi Tahap 13)
-- -----------------------------------------------------------------------------
COPY (SELECT * FROM v_order_dimensions)
    TO 'data/processed/12_order_dimensions.parquet' (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 13
-- =============================================================================
-- [x] Breakdown AOV drivers reconcile ke total locked KPI (Tahap 6)
-- [x] Tidak ada bahasa kausal di finding (lihat Causal Interpretation Boundaries)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
