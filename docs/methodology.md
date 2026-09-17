# Methodology — Online Retail Analytics

> Tahap 6 — Data Validation & KPI Lock
> Sumber: `analytical_dataset` & populasi turunannya (hasil `sql/05_kpi_definition.sql`)
> Status: 🔒 **LOCKED** (2026-09-17) — lihat Revision Log di bagian akhir untuk perubahan setelah tanggal ini

---

## 1. Validation Report

### 1.1 Structural Validation

| Check | Hasil | Status |
|---|---|---|
| Raw rows vs Analytical Dataset rows | 1,067,371 = 1,067,371 | ✅ PASS |
| Missing Customer ID reconciliation | 229,372 (in Revenue Pop) = 229,372 (Revenue − Customer Pop) | ✅ PASS |

| Kolom | Raw | Revenue Population | Customer Population | Cancellation Population | Non-Product Population |
|---|---|---|---|---|---|
| Distinct Invoice | 53,628 | 41,396 | — | 11,685 | — |
| Distinct StockCode | 5,305 | 4,974 | — | — | 12 |
| Distinct Customer ID | 5,942 | 5,855 | 5,855 | — | — |

> Catatan: 53,628 − 41,396 − 11,685 = 547 invoice yang tidak masuk ke Revenue
> maupun Cancellation Population — ini invoice yang seluruh baris-nya
> ter-exclude karena non-product-only, exact-duplicate-only, atau
> negative-price-only. Bukan anomaly baru, konsisten dengan treatment
> Tahap 5.

### 1.2 Business Validation

| Populasi | Row Count |
|---|---|
| Sales / Revenue Population | 1,006,044 |
| Cancellation / Return Population | 22,951 |
| Customer Population | 776,672 |
| Non-Product Population | 5,791 |

### 1.3 Revenue Validation — ✅ PASS

```
Line Revenue  = Quantity × Price
Order Revenue = SUM(Line Revenue) per Invoice
Total Revenue = SUM(Order Revenue)
```

| Metode Hitung | Total Revenue |
|---|---|
| SUM(Line Revenue) langsung | 19,646,574.86 |
| SUM(Order Revenue) (grouped by Invoice) | 19,646,574.86 |

**Reconciliation: MATCH 100%** (bukan sampling, dihitung dari seluruh baris `v_revenue_population`).

---

## 2. KPI Definitions — 🔒 LOCKED

> Definisi di bawah ini terkunci sejak tanggal validasi di atas. Tahap 7
> (EDA) dan seterusnya **tidak boleh mengubah definisi ini** tanpa melalui
> Dependency & Rollback Matrix: `Finding → kembali ke Tahap 5/6 → dicatat di
> Revision Log → re-validate → lanjut lagi`.

| KPI | Formula | Sumber Populasi | Nilai Terkunci |
|---|---|---|---|
| **Revenue** | `SUM(Quantity × Price)` | `v_revenue_population` | 19,646,574.86 |
| **Orders** | `COUNT(DISTINCT Invoice)` | `v_revenue_population` | 41,396 |
| **AOV (mean)** | `Revenue / Orders` | `v_revenue_population` | 474.60 |
| **AOV (median)** | `MEDIAN(order_revenue)` | `v_revenue_population` | 287.53 |
| **Basket Size (mean)** | `SUM(Quantity) / Orders` | `v_revenue_population` | 276.16 |
| **Total Quantity** | `SUM(Quantity)` | `v_revenue_population` | 11,432,042 |
| **Customer-level metrics** (RFM, Customer Value, dst) | — | `v_customer_population` | (dihitung di Tahap 11) |

**Catatan interpretasi wajib (Analytical Principle #4):**
AOV mean (474.60) jauh lebih tinggi dari AOV median (287.53) — distribusi
order value **sangat skewed** ke kanan (ada sejumlah kecil order bernilai
sangat besar yang menarik mean ke atas). Setiap laporan AOV di tahap
selanjutnya **wajib mencantumkan mean DAN median secara bersamaan**, tidak
boleh hanya salah satu.

---

## 3. Traceability Chain

Setiap angka KPI di atas bisa ditelusuri balik lewat:

```
validation_summary (05_validation_summary.parquet)
→ v_revenue_population / v_customer_population (view, sql/04_analytical_population.sql)
→ analytical_dataset (flagged, tidak ada baris dihapus)
→ raw_online_retail (raw CSV, tidak pernah diubah)
```

---

## 4. Revision Log

*(diisi HANYA kalau ada perubahan definisi KPI/population setelah lock di atas)*

| Tanggal | Definisi yang berubah | Alasan | Ditemukan di tahap mana |
|---|---|---|---|
| — | — | — | — |
