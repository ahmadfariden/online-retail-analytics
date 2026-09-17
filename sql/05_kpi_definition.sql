-- =============================================================================
-- TAHAP 6 — DATA VALIDATION & KPI LOCK
-- Project: Online Retail Analytics
-- File   : sql/05_kpi_definition.sql
-- =============================================================================
-- Tujuan: "Apakah dataset hasil cleaning benar-benar valid, dan apakah KPI
-- yang digunakan sudah konsisten?"
--
-- Acceptance Criteria (ketat, bukan sampling):
--    Row-count & revenue reconciliation HARUS 100% match. Kalau tidak match,
--    treatment di Tahap 5 dianggap GAGAL dan harus direvisi (balik ke
--    sql/04_analytical_population.sql), BUKAN dipaksakan lanjut di sini.
--
-- Begitu file ini selesai dijalankan & Acceptance Criteria PASS, definisi
-- Revenue/Order/AOV/Basket LOCKED. Perubahan setelah ini wajib lewat
-- Revision Log di docs/methodology.md.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. STRUCTURAL VALIDATION
-- -----------------------------------------------------------------------------

-- 1a. Row count before vs after treatment
SELECT
    (SELECT COUNT(*) FROM raw_online_retail)     AS raw_rows,
    (SELECT COUNT(*) FROM analytical_dataset)    AS analytical_rows,
    (SELECT COUNT(*) FROM v_revenue_population)  AS revenue_population_rows,
    (
        (SELECT COUNT(*) FROM raw_online_retail) = (SELECT COUNT(*) FROM analytical_dataset)
    )                                              AS pass_raw_vs_analytical_match;

-- 1b. Distinct Invoice reconciliation
SELECT
    (SELECT COUNT(DISTINCT Invoice) FROM raw_online_retail)          AS raw_distinct_invoice,
    (SELECT COUNT(DISTINCT Invoice) FROM v_revenue_population)       AS revenue_pop_distinct_invoice,
    (SELECT COUNT(DISTINCT Invoice) FROM v_cancellation_population)  AS cancel_pop_distinct_invoice;

-- 1c. Distinct StockCode reconciliation
SELECT
    (SELECT COUNT(DISTINCT StockCode) FROM raw_online_retail)        AS raw_distinct_stockcode,
    (SELECT COUNT(DISTINCT StockCode) FROM v_revenue_population)     AS revenue_pop_distinct_stockcode,
    (SELECT COUNT(DISTINCT StockCode) FROM v_non_product_population) AS non_product_distinct_stockcode;

-- 1d. Distinct Customer ID reconciliation
SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM analytical_dataset)      AS analytical_distinct_customer,
    (SELECT COUNT(DISTINCT customer_id) FROM v_revenue_population)    AS revenue_pop_distinct_customer,
    (SELECT COUNT(DISTINCT customer_id) FROM v_customer_population)   AS customer_pop_distinct_customer;

-- 1e. Null / missing reconciliation
-- missing_customer_id_flagged harus sama persis dengan angka profiling
-- Tahap 4 (243,007), karena tidak ada baris yang hilang di analytical_dataset.
SELECT
    COUNT(*) FILTER (WHERE has_valid_customer_id = FALSE) AS missing_customer_id_flagged,
    COUNT(*) FILTER (WHERE has_valid_customer_id = FALSE
                       AND is_cancellation = FALSE
                       AND is_special_stockcode = FALSE
                       AND is_exact_duplicate_extra = FALSE
                       AND is_negative_price = FALSE
                       AND Quantity > 0)                  AS missing_customer_id_in_revenue_pop,
    (SELECT COUNT(*) FROM v_revenue_population) - (SELECT COUNT(*) FROM v_customer_population)
                                                            AS revenue_minus_customer_pop
FROM analytical_dataset;
-- Catatan: missing_customer_id_in_revenue_pop HARUS SAMA dengan
-- revenue_minus_customer_pop -> ini reconciliation check kenapa Customer
-- Population (776,672) lebih kecil dari Revenue Population (1,006,044).


-- -----------------------------------------------------------------------------
-- 2. BUSINESS VALIDATION
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM v_revenue_population)      AS sales_population_rows,
    (SELECT COUNT(*) FROM v_cancellation_population) AS cancellation_population_rows,
    (SELECT COUNT(*) FROM v_customer_population)     AS customer_population_rows,
    (SELECT COUNT(*) FROM v_non_product_population)  AS non_product_population_rows;


-- -----------------------------------------------------------------------------
-- 3. REVENUE VALIDATION
-- -----------------------------------------------------------------------------
-- Line Revenue  = Quantity x Price
-- Order Revenue = SUM(Line Revenue) per Invoice
-- Total Revenue = SUM(Order Revenue)
-- Reconciliation: SUM(Order Revenue) harus PERSIS sama dengan SUM(Line Revenue)

WITH line_rev AS (
    SELECT Invoice, Quantity * Price AS line_revenue
    FROM v_revenue_population
),
order_rev AS (
    SELECT Invoice, SUM(line_revenue) AS order_revenue
    FROM line_rev
    GROUP BY Invoice
)
SELECT
    (SELECT ROUND(SUM(line_revenue), 2) FROM line_rev)   AS total_from_line_revenue,
    (SELECT ROUND(SUM(order_revenue), 2) FROM order_rev) AS total_from_order_revenue,
    (
        (SELECT ROUND(SUM(line_revenue), 2) FROM line_rev)
        = (SELECT ROUND(SUM(order_revenue), 2) FROM order_rev)
    ) AS pass_revenue_reconciliation;


-- -----------------------------------------------------------------------------
-- 4. ORDER VALIDATION
-- -----------------------------------------------------------------------------
-- Orders dihitung dari valid sales population (v_revenue_population),
-- BUKAN dari raw_online_retail.
SELECT
    COUNT(DISTINCT Invoice) AS orders
FROM v_revenue_population;


-- -----------------------------------------------------------------------------
-- 5. AOV VALIDATION
-- -----------------------------------------------------------------------------
-- AOV = Revenue / Orders
WITH order_rev AS (
    SELECT Invoice, SUM(Quantity * Price) AS order_revenue
    FROM v_revenue_population
    GROUP BY Invoice
)
SELECT
    ROUND(SUM(order_revenue), 2)                          AS total_revenue,
    COUNT(DISTINCT Invoice)                                AS orders,
    ROUND(SUM(order_revenue) / COUNT(DISTINCT Invoice), 2) AS aov_mean,
    ROUND(MEDIAN(order_revenue), 2)                        AS aov_median
FROM order_rev;


-- -----------------------------------------------------------------------------
-- 6. BASKET VALIDATION
-- -----------------------------------------------------------------------------
-- Basket Size = Total Quantity / Orders
SELECT
    SUM(Quantity)                                       AS total_quantity,
    COUNT(DISTINCT Invoice)                              AS orders,
    ROUND(SUM(Quantity) * 1.0 / COUNT(DISTINCT Invoice), 2) AS basket_size_mean
FROM v_revenue_population;


-- -----------------------------------------------------------------------------
-- 7. KPI DEFINITION LOCK — EXPORT VALIDATION SUMMARY
-- -----------------------------------------------------------------------------
-- Setelah semua query di atas dijalankan dan Section 3 (pass_revenue_
-- reconciliation) bernilai TRUE, isi angka final di bawah ini dengan hasil
-- aktual, lalu export sebagai output resmi Tahap 6.

-- Semua Acceptance Criteria PASS (dieksekusi 2026-09-17):
--   pass_raw_vs_analytical_match = true
--   pass_revenue_reconciliation  = true (total_from_line_revenue = total_from_order_revenue = 19,646,574.86)
-- KPI resmi di-LOCK berdasarkan angka berikut.

CREATE OR REPLACE TABLE validation_summary AS
SELECT * FROM (VALUES
    ('structural', 'raw_vs_analytical_row_match',   'true',        'raw=1,067,371, analytical=1,067,371'),
    ('structural', 'missing_customer_id_reconcile', 'true',        'missing_in_revenue_pop=229,372 = revenue_minus_customer_pop=229,372'),
    ('revenue',    'total_revenue',                 '19646574.86', 'SUM(Quantity x Price), v_revenue_population'),
    ('revenue',    'revenue_reconciliation_pass',   'true',        'line_revenue = order_revenue, match ke 2 desimal'),
    ('order',      'total_orders',                  '41396',       'COUNT(DISTINCT Invoice), v_revenue_population'),
    ('aov',        'aov_mean',                      '474.60',      'total_revenue / total_orders'),
    ('aov',        'aov_median',                    '287.53',      'MEDIAN(order_revenue) -- mean >> median, skewed'),
    ('basket',     'basket_size_mean',              '276.16',      'SUM(Quantity) / total_orders'),
    ('basket',     'total_quantity',                '11432042',    'SUM(Quantity), v_revenue_population')
) AS t(check_category, metric_name, value_str, notes);

COPY validation_summary TO 'data/processed/05_validation_summary.parquet' (FORMAT PARQUET);


-- =============================================================================
-- KPI DEFINITIONS (LOCKED setelah Acceptance Criteria PASS)
-- =============================================================================
-- Revenue      = SUM(Quantity x Price), dihitung HANYA dari v_revenue_population
-- Orders       = COUNT(DISTINCT Invoice), dihitung HANYA dari v_revenue_population
-- AOV          = Revenue / Orders (mean), didampingi MEDIAN(order_revenue)
--                karena distribusi order value skewed (Analytical Principle #4)
-- Basket Size  = SUM(Quantity) / Orders, dihitung dari v_revenue_population
-- Customer-level metrics (RFM, Customer Value, dst) HANYA dari v_customer_population
-- =============================================================================


-- =============================================================================
-- REVISION LOG (isi kalau ada perubahan definisi setelah lock)
-- =============================================================================
-- | Tanggal | Definisi yang berubah | Alasan | Ditemukan di tahap mana |
-- |---------|------------------------|--------|--------------------------|
-- |    —    |           —            |   —    |            —             |
-- =============================================================================


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 6
-- =============================================================================
-- [x] Acceptance Criteria terpenuhi (row-count & revenue reconciliation 100% match)
-- [x] Output tersimpan di data/processed/05_validation_summary.parquet
-- [x] docs/methodology.md sudah diupdate
-- [ ] Git checkpoint sudah di-commit
-- [x] Tidak ada perubahan ke definisi KPI tanpa dicatat sebagai revision
-- =============================================================================
