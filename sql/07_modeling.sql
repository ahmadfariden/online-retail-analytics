-- =============================================================================
-- TAHAP 8 — DATA MODELING
-- Project: Online Retail Analytics
-- File   : sql/07_modeling.sql
-- =============================================================================
-- Tujuan: merepresentasikan v_revenue_population (KPI locked, Tahap 6) dalam
-- bentuk star schema. Modeling TIDAK mengubah analytical population — hanya
-- reshape dari flat table jadi Dim/Fact.
--
-- Dimensions : Dim_Product, Dim_Customer, Dim_Country, Dim_Date
-- Facts      : Fact_Order_Lines (grain: 1 retained transaction line)
--              Fact_Orders      (grain: 1 Invoice)
--
-- Acceptance Criteria:
--   Row count Fact_Order_Lines = row count v_revenue_population (reconciliation
--   ulang, bukan asumsi).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. DIM_DATE
-- -----------------------------------------------------------------------------
-- Grain: 1 baris per tanggal kalender, mencakup seluruh rentang InvoiceDate
-- di v_revenue_population (bukan raw, supaya tidak ada tanggal "hantu" yang
-- sebenarnya sudah ter-exclude sepenuhnya).

CREATE OR REPLACE TABLE Dim_Date AS
WITH bounds AS (
    SELECT
        MIN(CAST(InvoiceDate AS DATE)) AS min_date,
        MAX(CAST(InvoiceDate AS DATE)) AS max_date
    FROM v_revenue_population
)
SELECT
    CAST(strftime(d, '%Y%m%d') AS INTEGER)      AS date_key,
    d                                           AS full_date,
    YEAR(d)                                     AS year,
    QUARTER(d)                                  AS quarter,
    MONTH(d)                                    AS month,
    MONTHNAME(d)                                AS month_name,
    DAY(d)                                      AS day,
    DAYOFWEEK(d)                                AS day_of_week_num,
    DAYNAME(d)                                  AS day_name,
    (DAYOFWEEK(d) IN (0, 6))                    AS is_weekend
FROM bounds, generate_series(bounds.min_date, bounds.max_date, INTERVAL 1 DAY) AS t(d);


-- -----------------------------------------------------------------------------
-- 2. DIM_PRODUCT
-- -----------------------------------------------------------------------------
-- Grain: 1 baris per StockCode yang MASIH ADA di v_revenue_population
-- (produk non-product & yang exclude total sudah tidak relevan di sini).
-- Description diambil versi terbanyak muncul (mode) karena profiling
-- menemukan 1 StockCode bisa punya beberapa varian Description (Tahap 4).

CREATE OR REPLACE TABLE Dim_Product AS
WITH desc_rank AS (
    SELECT
        StockCode,
        Description,
        COUNT(*) AS n,
        ROW_NUMBER() OVER (PARTITION BY StockCode ORDER BY COUNT(*) DESC) AS rn
    FROM v_revenue_population
    GROUP BY StockCode, Description
),
agg AS (
    SELECT
        StockCode,
        SUM(Quantity * Price) AS total_revenue,
        SUM(Quantity)         AS total_quantity,
        COUNT(DISTINCT Invoice) AS orders_containing_product
    FROM v_revenue_population
    GROUP BY StockCode
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.StockCode)   AS product_key,
    d.StockCode                                AS stock_code,
    d.Description                              AS description,
    a.total_revenue,
    a.total_quantity,
    a.orders_containing_product
FROM desc_rank d
JOIN agg a USING (StockCode)
WHERE d.rn = 1;


-- -----------------------------------------------------------------------------
-- 3. DIM_COUNTRY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE Dim_Country AS
SELECT
    ROW_NUMBER() OVER (ORDER BY Country) AS country_key,
    Country                              AS country_name
FROM (SELECT DISTINCT Country FROM v_revenue_population);


-- -----------------------------------------------------------------------------
-- 4. DIM_CUSTOMER
-- -----------------------------------------------------------------------------
-- Termasuk 1 baris khusus "Unknown Customer" (customer_key = -1) untuk
-- menampung baris Revenue Population yang Customer ID-nya NULL (22.77% dari
-- populasi -- lihat docs/assumptions_and_limitations.md). Ini standar
-- dimensional modeling: Fact table tidak boleh punya FK NULL.

CREATE OR REPLACE TABLE Dim_Customer AS
WITH known AS (
    SELECT
        customer_id,
        -- ambil country yang paling sering muncul untuk customer ini
        (SELECT Country
         FROM v_revenue_population r2
         WHERE r2.customer_id = r1.customer_id
         GROUP BY Country
         ORDER BY COUNT(*) DESC
         LIMIT 1)                                          AS primary_country,
        MIN(CAST(InvoiceDate AS DATE))                      AS first_purchase_date,
        SUM(Quantity * Price)                               AS total_revenue,
        COUNT(DISTINCT Invoice)                              AS total_orders
    FROM v_revenue_population r1
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id)   AS customer_key,
    customer_id,
    primary_country,
    first_purchase_date,
    total_revenue,
    total_orders,
    TRUE                                        AS is_known_customer
FROM known

UNION ALL

SELECT
    -1                    AS customer_key,
    NULL                  AS customer_id,
    NULL                  AS primary_country,
    NULL                  AS first_purchase_date,
    NULL                  AS total_revenue,
    NULL                  AS total_orders,
    FALSE                 AS is_known_customer;


-- -----------------------------------------------------------------------------
-- 5. FACT_ORDER_LINES
-- -----------------------------------------------------------------------------
-- Grain: satu baris = satu retained transaction line dari v_revenue_population.

CREATE OR REPLACE TABLE Fact_Order_Lines AS
SELECT
    ROW_NUMBER() OVER ()                                  AS order_line_key,
    r.Invoice                                             AS invoice,
    p.product_key,
    COALESCE(c.customer_key, -1)                          AS customer_key,
    co.country_key,
    CAST(strftime(CAST(r.InvoiceDate AS DATE), '%Y%m%d') AS INTEGER) AS date_key,
    r.InvoiceDate                                         AS invoice_datetime,
    r.Quantity                                            AS quantity,
    r.Price                                               AS price,
    r.Quantity * r.Price                                  AS line_revenue
    -- SENGAJA tidak di-ROUND() di sini. Kalau tiap baris dibulatkan lalu
    -- dijumlahkan across 1,006,044 baris, error pembulatan menumpuk dan
    -- menyebabkan selisih vs v_revenue_population (ditemukan saat validasi:
    -- 19,646,574.86 vs 19,646,574.84). Pembulatan HANYA dilakukan sekali di
    -- level agregasi akhir (Fact_Orders / laporan), bukan di grain baris.
FROM v_revenue_population r
JOIN Dim_Product p  ON p.stock_code = r.StockCode
JOIN Dim_Country co ON co.country_name = r.Country
LEFT JOIN Dim_Customer c ON c.customer_id = r.customer_id;


-- -----------------------------------------------------------------------------
-- 6. FACT_ORDERS
-- -----------------------------------------------------------------------------
-- Grain: satu baris = satu Invoice (agregasi dari Fact_Order_Lines).

CREATE OR REPLACE TABLE Fact_Orders AS
SELECT
    invoice,
    ANY_VALUE(customer_key)                    AS customer_key,
    ANY_VALUE(country_key)                     AS country_key,
    ANY_VALUE(date_key)                        AS date_key,
    MIN(invoice_datetime)                      AS order_datetime,
    ROUND(SUM(line_revenue), 2)                AS order_revenue,
    SUM(quantity)                              AS total_quantity,
    COUNT(DISTINCT product_key)                AS distinct_items,
    COUNT(*)                                   AS n_lines
FROM Fact_Order_Lines
GROUP BY invoice;


-- -----------------------------------------------------------------------------
-- 7. RECONCILIATION CHECK (Acceptance Criteria)
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM v_revenue_population)   AS revenue_population_rows,
    (SELECT COUNT(*) FROM Fact_Order_Lines)       AS fact_order_lines_rows,
    (
        (SELECT COUNT(*) FROM v_revenue_population) = (SELECT COUNT(*) FROM Fact_Order_Lines)
    )                                              AS pass_fact_order_lines_match,

    (SELECT COUNT(DISTINCT Invoice) FROM v_revenue_population) AS revenue_population_orders,
    (SELECT COUNT(*) FROM Fact_Orders)                          AS fact_orders_rows,
    (
        (SELECT COUNT(DISTINCT Invoice) FROM v_revenue_population) = (SELECT COUNT(*) FROM Fact_Orders)
    )                                              AS pass_fact_orders_match,

    (SELECT ROUND(SUM(Quantity * Price), 2) FROM v_revenue_population) AS revenue_population_total,
    -- PENTING: reconciliation total HARUS dari SUM(line_revenue) yang belum
    -- dibulatkan di Fact_Order_Lines, BUKAN dari SUM(order_revenue) di
    -- Fact_Orders. order_revenue di Fact_Orders sengaja dibulatkan PER
    -- INVOICE untuk keperluan display/pelaporan (nilai per order yang wajar
    -- ditampilkan ke user) -- menjumlahkan 41,396 nilai yang sudah dibulatkan
    -- lalu dibulatkan lagi menimbulkan "penny rounding problem" klasik
    -- (selisih beberapa sen, BUKAN data error). Untuk validasi kesetaraan
    -- total, selalu bandingkan terhadap sumber unrounded.
    (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)          AS fact_lines_total_unrounded,
    (
        (SELECT ROUND(SUM(Quantity * Price), 2) FROM v_revenue_population)
        = (SELECT ROUND(SUM(line_revenue), 2) FROM Fact_Order_Lines)
    )                                              AS pass_revenue_match,

    -- Info tambahan (bukan bagian Acceptance Criteria): selisih akibat
    -- rounding per-invoice di Fact_Orders, untuk transparansi.
    (SELECT ROUND(SUM(order_revenue), 2) FROM Fact_Orders)              AS fact_orders_total_rounded_per_invoice,
    ROUND(
        (SELECT ROUND(SUM(Quantity * Price), 2) FROM v_revenue_population)
        - (SELECT ROUND(SUM(order_revenue), 2) FROM Fact_Orders)
    , 2)                                           AS penny_rounding_diff;


-- -----------------------------------------------------------------------------
-- 8. EXPORT STAR SCHEMA (output resmi Tahap 8)
-- -----------------------------------------------------------------------------
COPY Dim_Date         TO 'data/processed/07_dim_date.parquet'         (FORMAT PARQUET);
COPY Dim_Product      TO 'data/processed/07_dim_product.parquet'      (FORMAT PARQUET);
COPY Dim_Country      TO 'data/processed/07_dim_country.parquet'      (FORMAT PARQUET);
COPY Dim_Customer     TO 'data/processed/07_dim_customer.parquet'     (FORMAT PARQUET);
COPY Fact_Order_Lines TO 'data/processed/07_fact_order_lines.parquet' (FORMAT PARQUET);
COPY Fact_Orders      TO 'data/processed/07_fact_orders.parquet'      (FORMAT PARQUET);


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 8
-- =============================================================================
-- [x] Acceptance Criteria terpenuhi (row count Fact_Order_Lines = v_revenue_population)
-- [x] Semua Dim/Fact table sudah dibuat sesuai grain yang didefinisikan
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
