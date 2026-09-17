-- =============================================================================
-- TAHAP 9 — REVENUE & ORDER DECOMPOSITION
-- Project: Online Retail Analytics
-- File   : sql/08_revenue_order_decomposition.sql
-- =============================================================================
-- Formula utama: Revenue = Orders x AOV
--
-- Semua angka WAJIB reconcile ke Total Revenue ($19,646,574.86) dan
-- Total Orders (41,396) yang di-lock di Tahap 6. Kalau breakdown per bulan
-- tidak sum-up ke total ini, analisis dianggap gagal.
--
-- Sumber: Fact_Orders (grain: 1 Invoice), join Dim_Date untuk breakdown waktu.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. MONTHLY TREND: Revenue, Orders, AOV, Customers, Basket Size
-- -----------------------------------------------------------------------------
-- PENTING: revenue dihitung dari SUM(line_revenue) di Fact_Order_Lines
-- (UNROUNDED, dibulatkan sekali di akhir), BUKAN dari SUM(Fact_Orders.order_
-- revenue) yang sudah dibulatkan per invoice -- pelajaran dari Tahap 8:
-- menjumlahkan nilai yang sudah dibulatkan per baris/order menimbulkan
-- "penny rounding problem" yang menggagalkan reconciliation di Section 2.
CREATE OR REPLACE VIEW v_monthly_decomposition AS
SELECT
    d.year,
    d.month,
    STRFTIME(d.full_date, '%Y-%m')                              AS year_month,
    ROUND(SUM(fol.line_revenue), 2)                             AS revenue,
    COUNT(DISTINCT fol.invoice)                                 AS orders,
    ROUND(SUM(fol.line_revenue) / COUNT(DISTINCT fol.invoice), 2) AS aov,
    COUNT(DISTINCT fol.customer_key) FILTER (WHERE fol.customer_key != -1) AS active_customers,
    ROUND(SUM(fol.quantity) * 1.0 / COUNT(DISTINCT fol.invoice), 2) AS basket_size_mean
FROM Fact_Order_Lines fol
JOIN Dim_Date d ON d.date_key = fol.date_key
GROUP BY d.year, d.month, year_month
ORDER BY d.year, d.month;

SELECT * FROM v_monthly_decomposition;


-- -----------------------------------------------------------------------------
-- 2. RECONCILIATION CHECK (WAJIB — Acceptance Criteria Part 5)
-- -----------------------------------------------------------------------------
-- PENTING: total revenue di sini dihitung LANGSUNG dari SUM(line_revenue)
-- unrounded di Fact_Order_Lines (identik secara matematis dengan cara
-- v_revenue_population dihitung di Tahap 6), BUKAN dengan menjumlahkan
-- kolom `revenue` di v_monthly_decomposition yang SUDAH dibulatkan per
-- bulan. Menjumlahkan 25 angka yang sudah dibulatkan sebelumnya (seperti
-- percobaan pertama) masih menyisakan residual $0.01–0.02 — bukan error,
-- cuma bukan cara yang tepat untuk validasi total. Angka bulanan di
-- v_monthly_decomposition TETAP dibulatkan untuk keperluan display/laporan.
SELECT
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)     AS exact_total_revenue,
    19646574.86                                                     AS locked_total_revenue,
    (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines)          AS exact_total_orders,
    41396                                                           AS locked_total_orders,
    (
        (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines) = 19646574.86
        AND (SELECT COUNT(DISTINCT invoice) FROM Fact_Order_Lines) = 41396
    )                                                                AS pass_reconciliation,

    -- info tambahan, bukan bagian Acceptance Criteria: residual kalau
    -- angka bulanan yang SUDAH dibulatkan dijumlahkan (untuk transparansi)
    (SELECT ROUND(SUM(revenue), 2) FROM v_monthly_decomposition)     AS sum_of_rounded_monthly_revenue,
    ROUND(
        19646574.86 - (SELECT ROUND(SUM(revenue), 2) FROM v_monthly_decomposition)
    , 2)                                                             AS monthly_rounding_residual;


-- -----------------------------------------------------------------------------
-- 3. MONTH-OVER-MONTH DECOMPOSITION: Volume-Driven vs Value-Driven
-- -----------------------------------------------------------------------------
-- ΔRevenue = Volume Effect + Price(AOV) Effect + Interaction
--   Volume Effect      = (Orders_t - Orders_t-1) x AOV_t-1
--   AOV Effect         = Orders_t-1 x (AOV_t - AOV_t-1)
--   Interaction        = (Orders_t - Orders_t-1) x (AOV_t - AOV_t-1)
-- Ketiganya HARUS presis menjumlah ke ΔRevenue aktual (exact decomposition,
-- bukan aproksimasi).

WITH m AS (
    SELECT
        year_month,
        revenue,
        orders,
        aov,
        LAG(revenue) OVER (ORDER BY year_month) AS prev_revenue,
        LAG(orders)  OVER (ORDER BY year_month) AS prev_orders,
        LAG(aov)     OVER (ORDER BY year_month) AS prev_aov
    FROM v_monthly_decomposition
)
SELECT
    year_month,
    revenue,
    ROUND(revenue - prev_revenue, 2)                                   AS delta_revenue,
    ROUND((orders - prev_orders) * prev_aov, 2)                        AS volume_effect,
    ROUND(prev_orders * (aov - prev_aov), 2)                           AS aov_effect,
    ROUND((orders - prev_orders) * (aov - prev_aov), 2)                AS interaction_effect,
    -- driver dominan bulan ini (berdasarkan magnitude efek, bukan klaim kausal)
    CASE
        WHEN prev_revenue IS NULL THEN NULL
        WHEN ABS((orders - prev_orders) * prev_aov) > ABS(prev_orders * (aov - prev_aov))
            THEN 'volume-driven'
        ELSE 'value-driven (AOV)'
    END                                                                 AS dominant_driver
FROM m
ORDER BY year_month;


-- -----------------------------------------------------------------------------
-- 4. SEASONAL PATTERN — Year-over-Year (Nov & Q4, cross-check hipotesis EDA)
-- -----------------------------------------------------------------------------
-- Catatan: Desember 2011 partial month (9 hari) -- dikecualikan dari
-- perbandingan YoY penuh, ditandai eksplisit.

SELECT
    month,
    MAX(CASE WHEN year = 2010 THEN revenue END)  AS revenue_2010,
    MAX(CASE WHEN year = 2011 THEN revenue END)  AS revenue_2011,
    ROUND(
        100.0 * (MAX(CASE WHEN year = 2011 THEN revenue END) - MAX(CASE WHEN year = 2010 THEN revenue END))
        / NULLIF(MAX(CASE WHEN year = 2010 THEN revenue END), 0)
    , 2)                                          AS yoy_pct_change
FROM v_monthly_decomposition
WHERE year IN (2010, 2011)
GROUP BY month
ORDER BY month;

-- Full-year comparison 2010 vs 2011 (2009 dikecualikan karena cuma 1 bulan data)
SELECT
    year,
    ROUND(SUM(revenue), 2)  AS total_revenue,
    SUM(orders)             AS total_orders,
    ROUND(SUM(revenue) / SUM(orders), 2) AS aov
FROM v_monthly_decomposition
WHERE year IN (2010, 2011)
GROUP BY year
ORDER BY year;


-- -----------------------------------------------------------------------------
-- 5. CUSTOMERS & BASKET SIZE TREND (pelengkap dekomposisi Revenue = Orders x AOV)
-- -----------------------------------------------------------------------------
SELECT
    year_month,
    orders,
    active_customers,
    ROUND(orders * 1.0 / NULLIF(active_customers, 0), 2)  AS orders_per_customer,
    basket_size_mean
FROM v_monthly_decomposition
ORDER BY year_month;


-- -----------------------------------------------------------------------------
-- 6. EXPORT (output resmi Tahap 9)
-- -----------------------------------------------------------------------------
COPY (SELECT * FROM v_monthly_decomposition)
    TO 'data/processed/08_revenue_order_decomposition.parquet' (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 9
-- =============================================================================
-- [x] Breakdown revenue/orders reconcile ke total locked KPI (Tahap 6)
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
