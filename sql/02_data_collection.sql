-- =============================================================================
-- TAHAP 3 — DATA COLLECTION
-- Project: Online Retail Analytics
-- File   : sql/02_data_collection.sql
-- =============================================================================
-- Tujuan:
--   - UCI sebagai primary source
--   - raw CSV sebagai source of truth (tidak pernah diubah)
--   - ingestion raw CSV ke DuckDB
--   - schema verification
--   - initial inventory
--   - provenance
--
-- Catatan governance:
--   - Prinsip #1 (Analytical Principles): Raw data tidak pernah diubah.
--     Tabel di bawah ini adalah representasi 1:1 dari CSV, TANPA transformasi,
--     TANPA filter, TANPA cleaning. Cleaning ada di Tahap 4 (03_profiling.sql
--     lanjut ke tahap cleaning), bukan di sini.
--   - Jika ada temuan baru yang butuh query tambahan di tahap Data Collection,
--     APPEND ke file ini, jangan bikin file baru.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. PROVENANCE
-- -----------------------------------------------------------------------------
-- Source      : UCI Machine Learning Repository — Online Retail II Dataset
-- URL         : https://archive.ics.uci.edu/dataset/502/online+retail+ii
-- File        : online_retail_II.csv
-- File size   : 92,628 KB
-- Downloaded  : 2019-12-02
-- Loaded into : retail.duckdb -> table raw_online_retail
-- Loaded on   : 2026-09-17
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- 2. INGESTION
-- -----------------------------------------------------------------------------
-- Path relatif terhadap root project (asumsi duckdb.exe dijalankan dari root
-- folder 'online-retail-analytics'). Kalau working directory beda, ganti ke
-- path absolut, gunakan forward slash '/', bukan backslash '\'.

CREATE TABLE IF NOT EXISTS raw_online_retail AS
SELECT *
FROM read_csv_auto(
    'data/raw/online_retail_II.csv',
    header      = true,
    all_varchar = false,
    sample_size = -1   -- scan seluruh baris untuk deteksi tipe kolom,
                        -- bukan cuma sample (Invoice bisa campur angka & huruf
                        -- karena invoice cancellation diawali huruf 'C')
);


-- -----------------------------------------------------------------------------
-- 3. SCHEMA VERIFICATION
-- -----------------------------------------------------------------------------
-- Expected: 8 kolom sesuai dokumentasi UCI
--   Invoice, StockCode, Description, Quantity, InvoiceDate, Price,
--   Customer ID, Country

DESCRIBE raw_online_retail;

-- Hasil terverifikasi (2026-09-17):
--   Invoice       varchar
--   StockCode     varchar
--   Description   varchar
--   Quantity      bigint
--   InvoiceDate   timestamp
--   Price         double
--   Customer ID   double   <- double, bukan varchar/int, karena ada baris
--                             dengan Customer ID kosong (NULL). Ini basis
--                             perhitungan "missing Customer ID" di Tahap 4.
--   Country       varchar
-- Status: MATCH dengan dokumentasi UCI (8 kolom).


-- -----------------------------------------------------------------------------
-- 4. INITIAL INVENTORY
-- -----------------------------------------------------------------------------

-- total baris
SELECT COUNT(*) AS total_rows
FROM raw_online_retail;
-- Hasil (2026-09-17): 1,067,371 baris

-- spot check isi data
SELECT *
FROM raw_online_retail
LIMIT 10;

-- rentang tanggal & cardinality utama (cross-check awal terhadap dokumentasi UCI)
SELECT
    MIN(InvoiceDate)              AS min_date,
    MAX(InvoiceDate)              AS max_date,
    COUNT(DISTINCT Invoice)       AS distinct_invoices,
    COUNT(DISTINCT "Customer ID") AS distinct_customers,
    COUNT(DISTINCT Country)       AS distinct_countries
FROM raw_online_retail;

-- Baseline hasil (2026-09-17) — dipakai sebagai referensi pembanding
-- kalau nanti ada perubahan angka setelah cleaning (Tahap 5):
--   min_date            : 2009-12-01 07:45:00
--   max_date            : 2011-12-09 12:50:00
--   distinct_invoices   : 53,628
--   distinct_customers  : 5,942
--   distinct_countries  : 43


-- -----------------------------------------------------------------------------
-- 5. CATATAN TEMUAN AWAL (bukan cleaning — hanya dicatat untuk Tahap 4)
-- -----------------------------------------------------------------------------
-- - Sebagian nilai "Customer ID" NULL -> perlu diukur persentasenya di
--   profiling (03_profiling.sql), bukan ditangani di sini.
-- - Kolom "Description" pada beberapa baris mengandung newline/line break
--   di tengah teks (bagian dari isi CSV asli, bukan artefak ingestion).
--   Dicatat sebagai potential data quality note untuk profiling.


-- -----------------------------------------------------------------------------
-- DEFINITION OF DONE — TAHAP 3
-- -----------------------------------------------------------------------------
-- [x] Raw CSV masuk ke data/raw/ (read-only, tidak diubah)
-- [x] Ingestion ke DuckDB berhasil, schema terverifikasi
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
