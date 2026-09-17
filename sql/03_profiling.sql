-- =============================================================================
-- TAHAP 4 — DATA PROFILING
-- Project: Online Retail Analytics
-- File   : sql/03_profiling.sql
-- =============================================================================
-- Tujuan:
--   - memahami struktur dataset
--   - mengidentifikasi masalah data
--   - mengukur kualitas data
--   - menemukan anomaly yang membutuhkan investigasi lebih lanjut
--
-- ⚠️ PENTING: Tahap ini TIDAK melakukan cleaning final. Profiling hanya
--    menjawab "Apa masalah yang ada di data?" — keputusan retain/exclude/flag
--    ada di Tahap 5 (Data Cleaning & Data Treatment).
--
-- Acceptance Criteria:
--   Semua kategori anomaly (missing, duplicate, cancellation, price/qty
--   anomaly, non-product stockcode) HARUS punya angka count/persentase,
--   bukan sekadar "sudah dicek".
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. BASELINE (referensi dari Tahap 3 - Data Collection)
-- -----------------------------------------------------------------------------
-- total_rows          : 1,067,371
-- distinct_invoices   : 53,628
-- distinct_customers  : 5,942
-- distinct_countries  : 43
-- date range          : 2009-12-01 s/d 2011-12-09


-- -----------------------------------------------------------------------------
-- 1. ROW COUNT & SCHEMA CHECK (ringkasan ulang, detail sudah di Tahap 3)
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM raw_online_retail;
DESCRIBE raw_online_retail;


-- -----------------------------------------------------------------------------
-- 2. MISSING CUSTOMER ID
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                   AS total_rows,
    COUNT(*) FILTER (WHERE "Customer ID" IS NULL)              AS missing_customer_id,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE "Customer ID" IS NULL)
        / COUNT(*), 2
    )                                                           AS pct_missing_customer_id
FROM raw_online_retail;


-- -----------------------------------------------------------------------------
-- 3. EXACT DUPLICATES (seluruh kolom identik)
-- -----------------------------------------------------------------------------
WITH dup_check AS (
    SELECT
        Invoice, StockCode, Description, Quantity,
        InvoiceDate, Price, "Customer ID", Country,
        COUNT(*) AS n
    FROM raw_online_retail
    GROUP BY ALL
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*)                       AS distinct_duplicate_groups,
    SUM(n)                         AS total_rows_involved,
    SUM(n - 1)                     AS extra_rows_if_deduped
FROM dup_check;


-- -----------------------------------------------------------------------------
-- 4. DUPLICATE PRODUCT LINES (Invoice + StockCode muncul >1x dalam 1 invoice)
-- -----------------------------------------------------------------------------
-- Beda dari exact duplicate: ini mendeteksi baris dengan Invoice+StockCode
-- sama tapi bisa jadi Quantity/Price/Description beda (butuh investigasi
-- business-level, bukan cuma exact match).
WITH line_check AS (
    SELECT
        Invoice, StockCode,
        COUNT(*) AS n_lines
    FROM raw_online_retail
    GROUP BY Invoice, StockCode
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*)   AS invoice_stockcode_combos_with_multiple_lines,
    SUM(n_lines) AS total_rows_involved
FROM line_check;


-- -----------------------------------------------------------------------------
-- 5. CANCELLATION INVOICES (Invoice diawali huruf 'C')
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                       AS total_rows,
    COUNT(*) FILTER (WHERE Invoice LIKE 'C%')                      AS cancellation_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE Invoice LIKE 'C%')
        / COUNT(*), 2)                                              AS pct_cancellation_rows,
    COUNT(DISTINCT Invoice) FILTER (WHERE Invoice LIKE 'C%')       AS cancellation_invoices,
    COUNT(DISTINCT Invoice)                                        AS total_invoices
FROM raw_online_retail;


-- -----------------------------------------------------------------------------
-- 6. NEGATIVE / ZERO / EXTREME QUANTITY
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE Quantity < 0)  AS negative_qty_rows,
    COUNT(*) FILTER (WHERE Quantity = 0)  AS zero_qty_rows,
    MIN(Quantity)                          AS min_qty,
    MAX(Quantity)                          AS max_qty,
    approx_quantile(Quantity, 0.25)        AS p25,
    approx_quantile(Quantity, 0.50)        AS median,
    approx_quantile(Quantity, 0.75)        AS p75,
    approx_quantile(Quantity, 0.99)        AS p99,
    approx_quantile(Quantity, 0.999)       AS p999
FROM raw_online_retail;

-- Extreme quantity: baris di luar 1st/99th percentile (kandidat threshold,
-- angka final ditentukan setelah lihat distribusi p99/p999 di atas)
SELECT COUNT(*) AS extreme_qty_candidate_rows
FROM raw_online_retail
WHERE Quantity > (SELECT approx_quantile(Quantity, 0.999) FROM raw_online_retail)
   OR Quantity < (SELECT approx_quantile(Quantity, 0.001) FROM raw_online_retail);

-- Top 10 quantity ekstrem (untuk investigasi manual)
SELECT Invoice, StockCode, Description, Quantity, Price, "Customer ID", Country
FROM raw_online_retail
ORDER BY ABS(Quantity) DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 7. NEGATIVE / ZERO / EXTREME PRICE
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE Price < 0)  AS negative_price_rows,
    COUNT(*) FILTER (WHERE Price = 0)  AS zero_price_rows,
    MIN(Price)                          AS min_price,
    MAX(Price)                          AS max_price,
    approx_quantile(Price, 0.25)        AS p25,
    approx_quantile(Price, 0.50)        AS median,
    approx_quantile(Price, 0.75)        AS p75,
    approx_quantile(Price, 0.99)        AS p99,
    approx_quantile(Price, 0.999)       AS p999
FROM raw_online_retail;

-- Extreme price candidate rows
SELECT COUNT(*) AS extreme_price_candidate_rows
FROM raw_online_retail
WHERE Price > (SELECT approx_quantile(Price, 0.999) FROM raw_online_retail);

-- Top 10 price ekstrem (untuk investigasi manual)
SELECT Invoice, StockCode, Description, Quantity, Price, "Customer ID", Country
FROM raw_online_retail
ORDER BY Price DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 8. NON-PRODUCT STOCKCODE
-- -----------------------------------------------------------------------------
-- StockCode yang secara pattern bukan produk fisik (fee, adjustment, postage,
-- bank charges, dll). Pattern di bawah berdasarkan known non-product codes
-- di dataset UCI Online Retail — perlu dicek ulang manual lewat DISTINCT
-- Description-nya, karena bisa ada varian lain.
SELECT
    StockCode,
    ANY_VALUE(Description) AS sample_description,
    COUNT(*)                AS n_rows
FROM raw_online_retail
WHERE StockCode IN ('POST', 'DOT', 'D', 'M', 'C2', 'BANK CHARGES', 'PADS', 'CRUK', 'AMAZONFEE')
   OR StockCode ~ '^[A-Za-z]+$'   -- StockCode full huruf (bukan alfanumerik campur angka, ciri khas produk)
GROUP BY StockCode
ORDER BY n_rows DESC;

-- Total dampaknya
SELECT
    COUNT(*) AS non_product_rows,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM raw_online_retail), 2) AS pct_non_product_rows
FROM raw_online_retail
WHERE StockCode IN ('POST', 'DOT', 'D', 'M', 'C2', 'BANK CHARGES', 'PADS', 'CRUK', 'AMAZONFEE')
   OR StockCode ~ '^[A-Za-z]+$';


-- -----------------------------------------------------------------------------
-- 9. COUNTRY CONCENTRATION
-- -----------------------------------------------------------------------------
SELECT
    Country,
    COUNT(*)                                                        AS n_rows,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)             AS pct_of_total_rows,
    COUNT(DISTINCT Invoice)                                         AS n_invoices,
    COUNT(DISTINCT "Customer ID")                                   AS n_customers
FROM raw_online_retail
GROUP BY Country
ORDER BY n_rows DESC;


-- -----------------------------------------------------------------------------
-- 10. EXACT CARDINALITY (per kolom)
-- -----------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT Invoice)       AS distinct_invoice,
    COUNT(DISTINCT StockCode)     AS distinct_stockcode,
    COUNT(DISTINCT Description)   AS distinct_description,
    COUNT(DISTINCT "Customer ID") AS distinct_customer_id,
    COUNT(DISTINCT Country)       AS distinct_country
FROM raw_online_retail;


-- -----------------------------------------------------------------------------
-- 11. EXPORT PROFILING SUMMARY (output resmi tahap ini)
-- -----------------------------------------------------------------------------
-- Angka di bawah adalah hasil eksekusi aktual (lihat docs/profiling_findings.md
-- untuk narasi & interpretasi lengkap per kategori).

CREATE OR REPLACE TABLE profiling_summary (
    check_category VARCHAR,
    metric_name    VARCHAR,
    value_num      DOUBLE,
    notes          VARCHAR
);

INSERT INTO profiling_summary VALUES
    ('missing_data', 'missing_customer_id_rows',          243007, 'dari 1,067,371 total baris'),
    ('missing_data', 'missing_customer_id_pct',            22.77, ''),

    ('duplicate',    'exact_duplicate_groups',             32907, ''),
    ('duplicate',    'exact_duplicate_extra_rows',         34335, '3.22% dari total baris'),
    ('duplicate',    'invoice_stockcode_multiline_combos', 42638, 'butuh investigasi business-level, bukan exact dup'),
    ('duplicate',    'invoice_stockcode_multiline_rows',   88585, ''),

    ('cancellation', 'cancellation_rows',                  19494, '1.83% dari total baris'),
    ('cancellation', 'cancellation_invoices',               8292, '15.46% dari total invoice'),

    ('quantity',     'negative_qty_rows',                  22950, '2.15% dari total baris'),
    ('quantity',     'zero_qty_rows',                          0, ''),
    ('quantity',     'min_qty',                          -80995, ''),
    ('quantity',     'max_qty',                            80995, ''),
    ('quantity',     'extreme_qty_candidate_rows',          1318, 'di luar P0.1-P99.9'),

    ('price',        'negative_price_rows',                    5, ''),
    ('price',        'zero_price_rows',                     6202, '0.58% dari total baris'),
    ('price',        'min_price',                      -53594.36, ''),
    ('price',        'extreme_price_candidate_rows',         747, 'mayoritas dari StockCode non-product (M/BANK CHARGES/AMAZONFEE), bukan harga produk'),

    ('stockcode',    'non_product_candidate_rows',          5861, '0.55% -- regex over-capture, lihat catatan whitelist di findings'),

    ('country',      'uk_rows_pct',                         91.94, ''),
    ('country',      'uk_invoices_pct',                     91.60, ''),

    ('cardinality',  'distinct_invoice',                    53628, ''),
    ('cardinality',  'distinct_stockcode',                   5305, ''),
    ('cardinality',  'distinct_description',                 5698, 'lebih besar dari distinct_stockcode -> indikasi deskripsi tidak konsisten per StockCode'),
    ('cardinality',  'distinct_customer_id',                 5942, ''),
    ('cardinality',  'distinct_country',                       43, '');

COPY profiling_summary TO 'data/processed/03_profiling_summary.parquet' (FORMAT PARQUET);

-- =============================================================================
-- DEFINITION OF DONE — TAHAP 4
-- =============================================================================
-- [x] Semua kategori anomaly di atas sudah punya angka count/persentase
-- [x] Output tersimpan di data/processed/03_profiling_summary.parquet
-- [x] docs/profiling_findings.md sudah diupdate
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
