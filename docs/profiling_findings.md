# Profiling Findings — Online Retail Analytics

> Tahap 4 — Data Profiling
> Sumber: `raw_online_retail` (DuckDB, `retail.duckdb`), hasil eksekusi `sql/03_profiling.sql`
> Total baris: **1,067,371** | Rentang tanggal: 2009-12-01 s/d 2011-12-09

> ⚠️ Dokumen ini murni **temuan**, bukan keputusan cleaning. Keputusan
> retain/exclude/flag ada di Tahap 5 (`docs` terkait Data Cleaning & Data Treatment).

---

## 1. Data Quality Summary

| Kategori | Jumlah Baris Terdampak | % dari Total |
|---|---|---|
| Missing Customer ID | 243,007 | 22.77% |
| Exact duplicate rows (extra jika dedup) | 34,335 | 3.22% |
| Cancellation invoice (rows) | 19,494 | 1.83% |
| Negative Quantity | 22,950 | 2.15% |
| Zero Quantity | 0 | 0.00% |
| Zero Price | 6,202 | 0.58% |
| Negative Price | 5 | 0.0005% |
| Non-product StockCode (raw candidate) | 5,861 | 0.55% |

---

## 2. Missing-Value Analysis

- **Customer ID**: 243,007 dari 1,067,371 baris (**22.77%**) tidak punya Customer ID.
  - Ini konsisten dengan Risk Register roadmap ("~25% di dataset UCI").
  - Berdampak langsung ke semua analisis Customer-level (RFM, Customer Value) —
    populasi customer harus dipisah eksplisit di Tahap 5 (Customer Population).
  - Ditemukan pola: baris dengan StockCode non-product (`BANK CHARGES`,
    `AMAZONFEE`, `M`) mayoritas juga `Customer ID = NULL` — konsisten karena
    baris tersebut bukan transaksi customer riil.

---

## 3. Duplicate Analysis

### 3.1 Exact Duplicates (seluruh kolom identik)
- 32,907 grup duplikat, melibatkan 67,242 baris.
- Jika dedup (sisakan 1 per grup), akan menghapus **34,335 baris (3.22%)**.

### 3.2 Duplicate Product Lines (Invoice + StockCode sama, muncul >1x)
- 42,638 kombinasi Invoice+StockCode punya lebih dari satu baris (88,585 baris total).
- **Catatan penting:** angka ini lebih besar dari exact duplicate — artinya banyak
  baris dengan Invoice+StockCode sama tapi Quantity/Price/Description berbeda.
  Ini butuh investigasi business-level di Tahap 5 (apakah ini re-entry harga
  berbeda, split shipment, atau kesalahan input), bukan langsung dihapus.

---

## 4. Cancellation Analysis

- 19,494 baris (**1.83%** dari total) adalah baris cancellation (Invoice diawali `C`).
- 8,292 dari 53,628 invoice (**15.46%**) adalah invoice cancellation.
- Sample data menunjukkan pola **pasangan sale–cancellation** yang jelas, misal:
  - Invoice `581483` (Qty +80,995) dipasangkan dengan `C581484` (Qty −80,995) —
    StockCode & Customer ID sama persis.
- Temuan ini akan dipakai di Tahap 5 untuk klasifikasi sales vs cancellation/return.

---

## 5. Quantity Anomaly Analysis

| Metrik | Nilai |
|---|---|
| Negative Quantity | 22,950 baris (2.15%) |
| Zero Quantity | 0 baris |
| Min | -80,995 |
| Max | 80,995 |
| P25 / Median / P75 | 1 / 3 / 10 |
| P99 / P99.9 | 112 / 616 |
| Extreme candidate (di luar P0.1–P99.9) | 1,318 baris |

**Catatan:**
- Distribusi Quantity **sangat skewed** — median cuma 3, tapi ada baris sampai
  80,995. Mean akan sangat menyesatkan tanpa median pendamping (sesuai
  Analytical Principle #4).
- Beberapa outlier ekstrem (misal customer `13902` dari Denmark membeli
  belasan ribu unit paper cups/plates di harga 0.1) terlihat seperti pola
  **wholesale/business account**, bukan retail biasa — perlu dicatat sebagai
  interpretasi khusus, bukan otomatis dibuang sebagai error.
- Pasangan extreme Quantity (misal 80,995 / -80,995) berkorelasi langsung
  dengan pasangan sale-cancellation di atas.

---

## 6. Price Anomaly Analysis

| Metrik | Nilai |
|---|---|
| Negative Price | 5 baris |
| Zero Price | 6,202 baris (0.58%) |
| Min Price | -53,594.36 |
| P75 / P99 / P99.9 | 4.15 / 18.89 / 303.32 |
| Extreme candidate (>P99.9) | 747 baris |

**Catatan penting:**
- Baris dengan Price paling ekstrem (18,910 – 38,970) **semuanya berasal dari
  StockCode non-product**: `M` (Manual), `BANK CHARGES`, `AMAZONFEE` — bukan
  harga produk fisik. Ini artinya "extreme Price" untuk *produk* kemungkinan
  jauh lebih kecil dari 747 baris; sebagian besar candidate ini sebenarnya
  masalah kategori StockCode, bukan masalah harga produk. Perlu di-split
  ulang di Tahap 5 setelah non-product StockCode dipisah.
- Price negatif (5 baris, kemungkinan besar `Adjust bad debt` / StockCode `B`)
  perlu investigasi manual satu per satu karena jumlahnya kecil.

---

## 7. Non-Product StockCode Analysis

| StockCode | Deskripsi | n_rows | Klasifikasi Awal |
|---|---|---|---|
| POST | POSTAGE | 2,122 | Non-product (ongkir) |
| DOT | DOTCOM POSTAGE | 1,446 | Non-product (ongkir) |
| M / m | Manual | 1,426 | Non-product (adjustment manual) |
| C2 | CARRIAGE | 282 | Non-product (ongkir) |
| D | Discount | 177 | Non-product (diskon) |
| S | SAMPLES | 104 | Non-product (sample gratis) |
| BANK CHARGES | Bank Charges | 102 | Non-product (biaya bank) |
| ADJUST | Adjustment by ... | 67 | Non-product (adjustment) |
| AMAZONFEE | Amazon Fee | 43 | Non-product (fee marketplace) |
| CRUK | CRUK Commission | 16 | Non-product (komisi) |
| B | Adjust bad debt | 6 | Non-product (adjustment) |
| GIFT | *(NULL)* | 1 | Perlu investigasi (deskripsi kosong) |
| **DCGSSGIRL** | GIRLS PARTY BAG | 25 | ⚠️ **Kemungkinan produk fisik asli** |
| **DCGSSBOY** | BOYS PARTY BAG | 23 | ⚠️ **Kemungkinan produk fisik asli** |
| **DCGSLBOY** | *(NULL)* | 1 | ⚠️ Perlu investigasi |
| **DCGSLGIRL** | *(NULL)* | 1 | ⚠️ Perlu investigasi |
| **PADS** | PADS TO MATCH ALL CUSHIONS | 19 | ⚠️ **Kemungkinan produk fisik asli** |

**Total tertangkap pattern regex "full huruf": 5,861 baris (0.55%)**

**Temuan kunci:** pattern regex `^[A-Za-z]+$` yang dipakai untuk deteksi awal
**over-capture** — StockCode `DCGSSGIRL`, `DCGSSBOY`, `PADS` ternyata
deskripsinya adalah produk fisik sungguhan (party bag, cushion pads), bukan
fee/adjustment. Klasifikasi `is_special_stockcode` di Tahap 5 harus pakai
**whitelist eksplisit** dari kode-kode fee/adjustment yang sudah dikonfirmasi
di atas (`POST`, `DOT`, `M`, `C2`, `D`, `S`, `BANK CHARGES`, `ADJUST`,
`AMAZONFEE`, `CRUK`, `B`), bukan pattern regex generik.

---

## 8. Country Concentration Analysis

- **United Kingdom mendominasi 91.94%** dari total baris (981,330 dari 1,067,371),
  49,108 dari 53,628 invoice (91.6%), dan 5,410 dari 5,942 customer (91.1%).
- 42 negara lain berbagi sisa 8.06% baris — mengonfirmasi Risk Register
  ("UK sangat dominan → Country analysis timpang").
- Beberapa negara punya pola tidak biasa dan perlu dicatat sebagai catatan
  interpretasi (bukan error):
  - **EIRE**: 806 invoice tapi cuma 5 distinct customer — sangat terkonsentrasi,
    kemungkinan besar akun business/reseller, bukan retail individual.
  - **Hong Kong**: 21 invoice tapi 0 distinct customer (seluruh baris
    Customer ID NULL) — konsisten dengan pola B2B/wholesale tanpa akun
    customer terdaftar.
- Implikasi ke Tahap 12 (Country Performance): analisis harus selalu
  menyandingkan **absolute vs relative performance**, tidak cukup absolute
  saja, karena size sample antar negara timpang jauh.

---

## 9. Exact Cardinality

| Kolom | Distinct Count |
|---|---|
| Invoice | 53,628 |
| StockCode | 5,305 |
| Description | 5,698 |
| Customer ID | 5,942 |
| Country | 43 |

**Temuan tambahan (di luar list aktivitas roadmap, tapi relevan):**
Jumlah distinct `Description` (5,698) **lebih besar** dari distinct
`StockCode` (5,305). Ini mengindikasikan satu StockCode bisa punya lebih dari
satu varian teks Description (typo, perubahan penamaan produk dari waktu ke
waktu, dsb). Perlu dicatat sebagai potential data quality issue untuk Tahap 5
— pertimbangkan standardisasi Description per StockCode (ambil versi
terbanyak/`mode`) kalau dipakai sebagai lookup produk.

---

## 10. Ringkasan Anomaly Inventory (untuk Acceptance Criteria)

| Anomaly Category | Metric | Value |
|---|---|---|
| Missing Data | % missing Customer ID | 22.77% |
| Duplicate | Exact duplicate extra rows | 34,335 (3.22%) |
| Duplicate | Invoice+StockCode multi-line combos | 42,638 |
| Cancellation | % cancellation rows | 1.83% |
| Cancellation | % cancellation invoices | 15.46% |
| Quantity | Negative Quantity rows | 22,950 (2.15%) |
| Quantity | Zero Quantity rows | 0 |
| Quantity | Extreme candidate (P0.1/P99.9) | 1,318 |
| Price | Zero Price rows | 6,202 (0.58%) |
| Price | Negative Price rows | 5 |
| Price | Extreme candidate (>P99.9) | 747 (mayoritas non-product) |
| StockCode | Non-product candidate rows | 5,861 (0.55%) — perlu whitelist ulang |
| Country | UK concentration | 91.94% rows |
| Cardinality | Description > StockCode mismatch | 5,698 vs 5,305 |

✅ Semua kategori anomaly wajib (missing, duplicate, cancellation, price/qty
anomaly, non-product stockcode) sudah punya angka temuan terdokumentasi —
**Acceptance Criteria Tahap 4 terpenuhi.**
