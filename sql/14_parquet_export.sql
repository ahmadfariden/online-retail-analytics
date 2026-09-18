-- =============================================================================
-- TAHAP 15 — PARQUET EXPORT
-- Project: Online Retail Analytics
-- File   : sql/14_parquet_export.sql
-- =============================================================================
-- Staging (Tahap 4-13, sudah ada)   -> data/processed/
-- Final BI layer (7 mart Tahap 14)  -> data/data_mart/
-- =============================================================================

COPY mart_revenue_daily        TO 'data/data_mart/mart_revenue_daily.parquet'        (FORMAT PARQUET);
COPY mart_aov_monthly          TO 'data/data_mart/mart_aov_monthly.parquet'          (FORMAT PARQUET);
COPY mart_basket_aov           TO 'data/data_mart/mart_basket_aov.parquet'           (FORMAT PARQUET);
COPY mart_customer_value       TO 'data/data_mart/mart_customer_value.parquet'       (FORMAT PARQUET);
COPY mart_product_performance  TO 'data/data_mart/mart_product_performance.parquet'  (FORMAT PARQUET);
COPY mart_country_performance  TO 'data/data_mart/mart_country_performance.parquet'  (FORMAT PARQUET);
COPY mart_data_quality_summary TO 'data/data_mart/mart_data_quality_summary.parquet' (FORMAT PARQUET);

-- Verifikasi: pastikan 7 file berhasil ter-export dengan row count yang benar
SELECT 'mart_revenue_daily' AS mart, COUNT(*) AS rows FROM mart_revenue_daily
UNION ALL SELECT 'mart_aov_monthly', COUNT(*) FROM mart_aov_monthly
UNION ALL SELECT 'mart_basket_aov', COUNT(*) FROM mart_basket_aov
UNION ALL SELECT 'mart_customer_value', COUNT(*) FROM mart_customer_value
UNION ALL SELECT 'mart_product_performance', COUNT(*) FROM mart_product_performance
UNION ALL SELECT 'mart_country_performance', COUNT(*) FROM mart_country_performance
UNION ALL SELECT 'mart_data_quality_summary', COUNT(*) FROM mart_data_quality_summary;


-- =============================================================================
-- DEFINITION OF DONE — TAHAP 15
-- =============================================================================
-- [x] Semua mart ter-export ke data/data_mart/ dalam format Parquet
-- [ ] Git checkpoint sudah di-commit
-- =============================================================================
