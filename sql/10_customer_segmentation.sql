-- =============================================================================
-- TAHAP 11 — CUSTOMER SEGMENTATION
-- Project: Online Retail Analytics
-- File   : sql/10_customer_segmentation.sql
-- =============================================================================
-- Tetap: Customer ID valid only (customer_key != -1, Customer Population
-- dari Tahap 5/6). Threshold RFM pakai QUARTIL DARI DISTRIBUSI AKTUAL data
-- ini, BUKAN skala template generik (misal "R < 30 hari = aktif" tanpa
-- dasar distribusi).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. RFM BASE CALCULATION (per customer, Customer Population only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_rfm AS
WITH reference_date AS (
    SELECT MAX(invoice_datetime) AS ref_date FROM Fact_Order_Lines
),
customer_orders AS (
    SELECT
        fol.customer_key,
        dc.customer_id,
        MAX(fol.invoice_datetime)                    AS last_purchase_date,
        COUNT(DISTINCT fol.invoice)                   AS frequency,
        SUM(fol.line_revenue)                         AS monetary
    FROM Fact_Order_Lines fol
    JOIN Dim_Customer dc ON dc.customer_key = fol.customer_key
    WHERE fol.customer_key != -1   -- Customer Population only (exclude Unknown)
    GROUP BY fol.customer_key, dc.customer_id
)
SELECT
    co.customer_key,
    co.customer_id,
    co.last_purchase_date,
    DATE_DIFF('day', CAST(co.last_purchase_date AS DATE), CAST(r.ref_date AS DATE)) AS recency_days,
    co.frequency,
    co.monetary                                       AS monetary   -- UNROUNDED, dibulatkan hanya saat display
FROM customer_orders co, reference_date r;


-- -----------------------------------------------------------------------------
-- 2. QUARTILE SCORING (berbasis distribusi aktual — NTILE(4))
-- -----------------------------------------------------------------------------
-- R: recency lebih KECIL = lebih baik -> quartile dibalik (NTILE ASC, tapi
--    skor tinggi untuk recency rendah)
-- F, M: nilai lebih BESAR = lebih baik -> skor tinggi untuk nilai tinggi

CREATE OR REPLACE VIEW v_customer_rfm_scored AS
SELECT
    customer_key,
    customer_id,
    recency_days,
    frequency,
    monetary,
    (5 - NTILE(4) OVER (ORDER BY recency_days ASC))   AS r_score,  -- recency kecil -> score besar
    NTILE(4) OVER (ORDER BY frequency ASC)            AS f_score,
    NTILE(4) OVER (ORDER BY monetary ASC)             AS m_score
FROM v_customer_rfm;

-- Cek threshold aktual per kuartil (untuk transparansi -- BUKAN angka arbitrer)
SELECT
    'recency_days' AS metric,
    MIN(recency_days) AS min_val,
    approx_quantile(recency_days, 0.25) AS q1,
    approx_quantile(recency_days, 0.50) AS q2,
    approx_quantile(recency_days, 0.75) AS q3,
    MAX(recency_days) AS max_val
FROM v_customer_rfm
UNION ALL
SELECT 'frequency', MIN(frequency), approx_quantile(frequency,0.25),
       approx_quantile(frequency,0.50), approx_quantile(frequency,0.75), MAX(frequency)
FROM v_customer_rfm
UNION ALL
SELECT 'monetary', MIN(monetary), approx_quantile(monetary,0.25),
       approx_quantile(monetary,0.50), approx_quantile(monetary,0.75), MAX(monetary)
FROM v_customer_rfm;


-- -----------------------------------------------------------------------------
-- 3. SEGMENT ASSIGNMENT (berdasarkan kombinasi skor kuartil aktual)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_segment AS
SELECT
    *,
    CASE
        WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                THEN 'Loyal'
        WHEN r_score = 4 AND f_score = 1                  THEN 'New / One-Time (Recent)'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk (High Value, Belum Kembali)'
        WHEN r_score = 1 AND f_score = 1                  THEN 'Lost / Hibernating'
        ELSE 'Standard'
    END AS segment
FROM v_customer_rfm_scored;

SELECT
    segment,
    COUNT(*)                                                      AS n_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)           AS pct_customers,
    ROUND(SUM(monetary), 2)                                       AS segment_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_revenue,
    ROUND(AVG(recency_days), 1)                                   AS avg_recency,
    ROUND(AVG(frequency), 1)                                      AS avg_frequency,
    ROUND(AVG(monetary), 2)                                       AS avg_monetary
FROM v_customer_segment
GROUP BY segment
ORDER BY segment_revenue DESC;


-- -----------------------------------------------------------------------------
-- 4. SEGMENT RECONCILIATION (Definition of Done)
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM Dim_Customer WHERE is_known_customer = TRUE) AS customer_population_dim,
    (SELECT COUNT(*) FROM v_customer_segment)                          AS segmented_customers,
    (
        (SELECT COUNT(*) FROM Dim_Customer WHERE is_known_customer = TRUE)
        = (SELECT COUNT(*) FROM v_customer_segment)
    )                                                                    AS pass_customer_count_match,

    (SELECT ROUND(SUM(monetary), 2) FROM v_customer_segment)             AS segmented_total_revenue,
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines WHERE customer_key != -1) AS customer_pop_total_revenue,
    (
        (SELECT ROUND(SUM(monetary), 2) FROM v_customer_segment)
        = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines WHERE customer_key != -1)
    )                                                                    AS pass_revenue_match;


-- -----------------------------------------------------------------------------
-- 5. ONE-TIME VS REPEAT (recompute untuk konsistensi dengan EDA Tahap 7)
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE frequency = 1)                          AS one_time_customers,
    COUNT(*) FILTER (WHERE frequency > 1)                          AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE frequency = 1) / COUNT(*), 2) AS pct_one_time,
    ROUND(100.0 * COUNT(*) FILTER (WHERE frequency > 1) / COUNT(*), 2) AS pct_repeat
FROM v_customer_rfm;


-- -----------------------------------------------------------------------------
-- 6. CUSTOMER REVENUE CONCENTRATION (quintile, recompute untuk konsistensi)
-- -----------------------------------------------------------------------------
WITH ranked AS (
    SELECT
        customer_id, monetary,
        NTILE(5) OVER (ORDER BY monetary DESC) AS revenue_quintile
    FROM v_customer_rfm
)
SELECT
    revenue_quintile,
    COUNT(*)                                                     AS n_customers,
    ROUND(SUM(monetary), 2)                                      AS revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_of_total_revenue
FROM ranked
GROUP BY revenue_quintile
ORDER BY revenue_quintile;


-- -----------------------------------------------------------------------------
-- 7. EXPORT (output resmi Tahap 11)
-- -----------------------------------------------------------------------------
COPY (SELECT * FROM v_customer_segment)
    TO 'data/processed/10_customer_segmentation.parquet' (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 11
-- =============================================================================
-- [x] Segment reconcile ke Customer Population (Tahap 5)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
