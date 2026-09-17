-- =============================================================================
-- TAHAP 5 — DATA CLEANING & DATA TREATMENT
-- Project: Online Retail Analytics
-- File   : sql/04_analytical_population.sql
-- =============================================================================
-- Tujuan: "Setelah mengetahui masalah data (Tahap 4), bagaimana masalah
-- tersebut ditangani?"
--
-- Prinsip yang dipegang di file ini (Analytical Principles #1 & #2):
--   1. raw_online_retail TIDAK PERNAH diubah/di-drop barisnya.
--   2. Setiap keputusan treatment (retained/excluded/flagged) ditandai lewat
--      KOLOM FLAG di analytical_dataset, bukan dihapus diam-diam.
--      Justifikasi tiap flag ada di komentar masing-masing bagian, dan wajib
--      disalin ke docs/assumptions_and_limitations.md.
--
-- Referensi temuan: docs/profiling_findings.md (Tahap 4)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. BUILD ANALYTICAL DATASET (dengan flag, tanpa menghapus baris apapun)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE analytical_dataset AS
WITH base AS (
    SELECT
        *,
        CAST("Customer ID" AS VARCHAR) AS customer_id_str,  -- Data Types: Customer ID -> string/categorical
        ROW_NUMBER() OVER (
            PARTITION BY Invoice, StockCode, Description, Quantity,
                         InvoiceDate, Price, "Customer ID", Country
            ORDER BY Invoice
        ) AS dup_row_num
    FROM raw_online_retail
)
SELECT
    Invoice,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    Price,
    "Customer ID"                                   AS customer_id,
    customer_id_str,
    Country,

    -- ===== FLAGS =====

    -- Cancellation: Invoice diawali huruf 'C'.
    -- Justifikasi: pola UCI dataset resmi menandai retur/cancellation dengan
    -- prefix 'C' pada Invoice. Dikonfirmasi di profiling: pasangan sale-cancel
    -- match persis di Quantity (misal 80995 vs -80995) untuk StockCode +
    -- Customer ID yang sama.
    (Invoice LIKE 'C%')                              AS is_cancellation,

    -- Non-product StockCode: WHITELIST eksplisit, BUKAN regex.
    -- Justifikasi: profiling Tahap 4 menemukan regex '^[A-Za-z]+$' over-capture
    -- (DCGSSGIRL/DCGSSBOY/PADS ternyata produk fisik asli, bukan fee/adjustment).
    -- Whitelist ini hanya berisi kode yang sample Description-nya sudah
    -- dikonfirmasi manual sebagai fee/adjustment/ongkir/diskon.
    (UPPER(StockCode) IN (
        'POST', 'DOT', 'M', 'C2', 'D', 'S',
        'BANK CHARGES', 'ADJUST', 'AMAZONFEE', 'CRUK', 'B'
    ))                                                AS is_special_stockcode,

    -- Negative Quantity yang BUKAN cancellation invoice.
    -- Justifikasi: profiling menunjukkan negative_qty_rows (22,950) > jumlah
    -- cancellation_rows (19,494) -> ada ~3,456 baris negative Quantity yang
    -- Invoice-nya TIDAK diawali 'C'. Ini bukan retur resmi, kemungkinan
    -- adjustment/loss/damage. Ditandai terpisah untuk investigasi, TIDAK
    -- otomatis disamakan dengan cancellation.
    (Quantity < 0 AND Invoice NOT LIKE 'C%')          AS is_negative_qty_unclassified,

    -- Zero Price: revenue kontribusinya otomatis 0 (Qty x 0), tapi baris
    -- tetap ada untuk analisis non-revenue (misal Orders/Basket kalau baris
    -- ini bagian dari invoice yang juga punya baris berbayar).
    -- Justifikasi: kemungkinan besar representasi free sample/promo item.
    (Price = 0)                                       AS is_zero_price,

    -- Negative Price: HANYA 5 baris di seluruh dataset (dari profiling).
    -- Justifikasi: nilai sangat kecil populasinya, dan sample menunjukkan
    -- terkait StockCode 'B' (Adjust bad debt) -> ini bukan transaksi sales,
    -- melainkan adjustment akuntansi. Diflag terpisah, dikeluarkan dari
    -- Revenue Population (lihat Section 2).
    (Price < 0)                                       AS is_negative_price,

    -- Exact duplicate: baris ke-2 dst dari grup yang seluruh 8 kolomnya identik
    -- (termasuk InvoiceDate sampai ke detik). Justifikasi: exact match di
    -- timestamp sampai ke detik untuk 8 kolom sekaligus, dari 34,335 baris,
    -- sangat tidak mungkin representasi 2 transaksi independen yang genuinely
    -- terjadi persis bersamaan -> diperlakukan sebagai duplicate entry.
    -- Hanya baris pertama (dup_row_num = 1) yang di-retain di Revenue
    -- Population; baris selanjutnya di-flag TRUE (redundant).
    (dup_row_num > 1)                                 AS is_exact_duplicate_extra,

    -- Customer ID valid (dipakai untuk Customer Population)
    ("Customer ID" IS NOT NULL)                       AS has_valid_customer_id

FROM base;


-- -----------------------------------------------------------------------------
-- 2. DEFINE ANALYTICAL POPULATIONS (view, bukan tabel terpisah -> selalu
--    konsisten dengan analytical_dataset)
-- -----------------------------------------------------------------------------

-- 2a. TRANSACTION / REVENUE POPULATION
--     Dipakai untuk: Revenue, Orders, AOV, Basket, Product, Country
--     Exclude: cancellation, special stockcode, exact duplicate extra,
--              negative price, dan quantity/price yang tidak masuk akal
--              untuk representasi sales riil (qty <= 0 atau price < 0).
--     Catatan: is_zero_price TIDAK di-exclude di sini (baris tetap dihitung
--     untuk Orders/Basket), karena kontribusi revenue-nya otomatis nol,
--     TIDAK mendistorsi SUM(Revenue).
CREATE OR REPLACE VIEW v_revenue_population AS
SELECT *
FROM analytical_dataset
WHERE is_cancellation = FALSE
  AND is_special_stockcode = FALSE
  AND is_exact_duplicate_extra = FALSE
  AND is_negative_price = FALSE
  AND Quantity > 0;

-- 2b. CUSTOMER POPULATION
--     Dipakai untuk: RFM, Customer Value, Repeat Purchase, Customer Revenue
--     Basis: Revenue Population + Customer ID valid.
CREATE OR REPLACE VIEW v_customer_population AS
SELECT *
FROM v_revenue_population
WHERE has_valid_customer_id = TRUE;

-- 2c. RETURN / CANCELLATION POPULATION
--     Dianalisis terpisah (bukan dicampur ke Revenue Population).
CREATE OR REPLACE VIEW v_cancellation_population AS
SELECT *
FROM analytical_dataset
WHERE is_cancellation = TRUE
   OR is_negative_qty_unclassified = TRUE;

-- 2d. NON-PRODUCT POPULATION
--     Diklasifikasikan terpisah; dikeluarkan hanya dari KPI yang tidak relevan
--     (misal Product Analysis), TETAP bisa dipakai untuk analisis lain
--     (misal total fee/ongkir kalau dibutuhkan di masa depan).
CREATE OR REPLACE VIEW v_non_product_population AS
SELECT *
FROM analytical_dataset
WHERE is_special_stockcode = TRUE;


-- -----------------------------------------------------------------------------
-- 3. RECONCILIATION CHECK (sanity check sebelum export)
-- -----------------------------------------------------------------------------
-- Total baris di 4 populasi + baris yang exact-duplicate-extra harus balik
-- ke total raw (dengan overlap yang jelas, bukan row count buta -- populasi
-- BISA overlap, misal is_negative_qty_unclassified bisa juga zero customer id).

SELECT
    (SELECT COUNT(*) FROM raw_online_retail)          AS raw_total_rows,
    (SELECT COUNT(*) FROM analytical_dataset)          AS analytical_dataset_rows,
    (SELECT COUNT(*) FROM v_revenue_population)        AS revenue_population_rows,
    (SELECT COUNT(*) FROM v_customer_population)        AS customer_population_rows,
    (SELECT COUNT(*) FROM v_cancellation_population)    AS cancellation_population_rows,
    (SELECT COUNT(*) FROM v_non_product_population)     AS non_product_population_rows;

-- Catatan: analytical_dataset_rows HARUS SAMA dengan raw_total_rows
-- (karena tidak ada baris yang dihapus di tahap ini, hanya ditandai).


-- -----------------------------------------------------------------------------
-- 4. EXPORT — cleaned analytical dataset (output resmi Tahap 5)
-- -----------------------------------------------------------------------------
COPY analytical_dataset TO 'data/processed/04_online_retail_clean.parquet' (FORMAT PARQUET);


-- =============================================================================
-- RINGKASAN KEPUTUSAN TREATMENT (salin ke docs/assumptions_and_limitations.md)
-- =============================================================================
-- | Isu                                | Keputusan                          | Justifikasi                                            |
-- |-------------------------------------|-------------------------------------|---------------------------------------------------------|
-- | Cancellation invoice (Invoice 'C%')  | Excluded dari Revenue Population    | Bukan sales riil, dianalisis terpisah sbg Return Pop.   |
-- | Non-product StockCode (whitelist)    | Excluded dari Revenue Population    | Bukan produk fisik (fee/ongkir/adjustment/diskon).      |
-- | Negative Qty, non-cancellation       | Flagged, excluded dari Revenue Pop  | ~3,456 baris tidak match pola cancellation resmi.       |
-- | Zero Price                           | Retained di Revenue Population      | Kontribusi revenue = 0, tidak mendistorsi SUM(Revenue). |
-- | Negative Price (5 baris)             | Excluded dari Revenue Population    | Adjustment akuntansi (bad debt), bukan transaksi sales. |
-- | Exact duplicate (34,335 extra rows)  | Excluded (retain 1 per grup)        | Match identik di 8 kolom termasuk timestamp ke-detik.   |
-- | Invoice+StockCode multi-line (bukan exact dup) | Retained, tidak diubah   | Bisa jadi split shipment/harga beda, bukan error.       |
-- | Missing Customer ID (22.77%)         | Retained di Revenue Population, excluded dari Customer Population | Tetap valid utk Revenue/Order, tidak valid utk analisis customer-level. |
--
-- =============================================================================
-- DEFINITION OF DONE — TAHAP 5
-- =============================================================================
-- [ ] Acceptance Criteria terpenuhi (semua treatment punya justifikasi tertulis)
-- [ ] Output tersimpan di data/processed/04_online_retail_clean.parquet
-- [ ] docs/assumptions_and_limitations.md sudah diupdate
-- [ ] Git checkpoint sudah di-commit
-- [ ] Tidak ada perubahan ke definisi population tanpa dicatat sebagai revision
-- =============================================================================
