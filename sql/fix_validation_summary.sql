-- =============================================================================
-- FIX — Re-isi validation_summary yang ternyata masih placeholder (NULL)
-- =============================================================================
-- Angka di bawah ini SAMA PERSIS dengan yang sudah divalidasi di Tahap 6
-- (semua Acceptance Criteria PASS, lihat docs/methodology.md).

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

-- Verifikasi
SELECT * FROM validation_summary;
