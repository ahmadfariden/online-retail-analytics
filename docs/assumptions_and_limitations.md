# Assumptions & Limitations — Online Retail Analytics

> Tahap 5 — Data Cleaning & Data Treatment
> Sumber: `analytical_dataset` (DuckDB, hasil `sql/04_analytical_population.sql`)
> Base: `raw_online_retail`, 1,067,371 baris (raw tidak pernah diubah)

---

## 1. Reconciliation Check

| Tabel / View | Row Count | % dari Raw |
|---|---|---|
| `raw_online_retail` | 1,067,371 | 100.00% |
| `analytical_dataset` (raw + flag, tidak ada baris dihapus) | 1,067,371 | 100.00% |
| `v_revenue_population` | 1,006,044 | 94.25% |
| `v_customer_population` | 776,672 | 72.78% |
| `v_cancellation_population` | 22,951 | 2.15% |
| `v_non_product_population` | 5,791 | 0.54% |

✅ `analytical_dataset_rows = raw_total_rows` — mengonfirmasi tidak ada baris
yang di-drop diam-diam di tahap ini; semua treatment dilakukan lewat flag.

---

## 2. Treatment Decisions & Justifications

| Isu | Keputusan | Justifikasi |
|---|---|---|
| Cancellation invoice (`Invoice LIKE 'C%'`) | Excluded dari Revenue Population, dipisah jadi Return/Cancellation Population | Bukan sales riil. Dikonfirmasi di profiling: pasangan sale-cancel match persis di Quantity untuk StockCode & Customer ID yang sama (misal +80,995 vs -80,995). |
| Non-product StockCode | Excluded dari Revenue Population via **whitelist eksplisit** (`POST, DOT, M, C2, D, S, BANK CHARGES, ADJUST, AMAZONFEE, CRUK, B`) | Profiling menemukan regex generik over-capture — `DCGSSGIRL`, `DCGSSBOY`, `PADS` ternyata produk fisik asli (dikonfirmasi lewat sample Description). Whitelist hanya berisi kode yang deskripsinya sudah dicek manual sebagai fee/ongkir/adjustment/diskon. |
| Negative Quantity, bukan cancellation (`Quantity < 0 AND Invoice NOT LIKE 'C%'`) | Flagged (`is_negative_qty_unclassified`), excluded dari Revenue Population, dimasukkan ke Cancellation/Return Population | Profiling menunjukkan negative_qty_rows (22,950) > cancellation_rows (19,494) — ada ±3,457 baris negative Quantity yang tidak mengikuti pola cancellation resmi (Invoice tanpa prefix 'C'). Kemungkinan adjustment/loss/damage; dipisah agar tidak disamakan dengan retur resmi tanpa bukti. |
| Zero Price (6,202 baris) | **Retained** di Revenue Population | Kontribusi ke SUM(Revenue) otomatis 0 (Qty × 0), tidak mendistorsi total revenue. Baris tetap relevan untuk Orders/Basket kalau merupakan bagian dari invoice campuran (ada baris lain yang berbayar). |
| Negative Price (5 baris) | Excluded dari Revenue Population | Populasi sangat kecil (5 baris), sample menunjukkan terkait StockCode `B` ("Adjust bad debt") — ini adjustment akuntansi, bukan transaksi sales riil. |
| Exact duplicate (34,335 baris "extra") | Excluded dari Revenue Population (retain hanya 1 per grup, sisanya diflag `is_exact_duplicate_extra`) | Match identik di seluruh 8 kolom termasuk `InvoiceDate` sampai ke detik. Kemungkinan 2 transaksi independen yang genuinely terjadi persis bersamaan di semua kolom dianggap sangat kecil — diperlakukan sebagai duplicate entry sistem. |
| Invoice+StockCode multi-line (42,638 kombinasi, BUKAN exact duplicate) | **Retained, tidak diubah** | Quantity/Price/Description bisa berbeda antar baris — berpotensi split shipment atau harga berbeda dalam transaksi yang sama, bukan otomatis error. Tidak ada justifikasi kuat untuk menghapus. |
| Missing Customer ID (243,007 baris, 22.77%) | Retained di Revenue Population, **excluded** dari Customer Population | Baris tetap valid untuk analisis Revenue/Order/Basket (grain: transaction line / order), tapi tidak bisa dipakai untuk analisis customer-level (RFM, Customer Value) karena tidak ada identitas customer. |

---

## 3. Analytical Population Definitions

| Populasi | Definisi (filter) | Row Count | Dipakai untuk |
|---|---|---|---|
| **Transaction / Revenue Population** | `NOT is_cancellation AND NOT is_special_stockcode AND NOT is_exact_duplicate_extra AND NOT is_negative_price AND Quantity > 0` | 1,006,044 | Revenue, Orders, AOV, Basket, Product, Country |
| **Customer Population** | Revenue Population `AND has_valid_customer_id` | 776,672 | RFM, Customer Revenue, Repeat Purchase, Customer Value |
| **Return / Cancellation Population** | `is_cancellation OR is_negative_qty_unclassified` | 22,951 | Analisis retur (terpisah dari sales) |
| **Non-Product Population** | `is_special_stockcode` (whitelist) | 5,791 | Dikeluarkan dari KPI produk fisik, tersedia untuk analisis fee/ongkir kalau dibutuhkan |

> Catatan: populasi-populasi ini **bisa overlap secara sumber data** (misal
> satu baris exact-duplicate-extra juga bisa kebetulan cancellation), tapi
> tidak saling tumpang tindih secara definisi pemakaian — masing-masing
> populasi punya tujuan analisis yang berbeda dan tidak dicampur.

---

## 4. Known Limitations (dibawa terus ke tahap berikutnya)

- **Missing Customer ID (22.77%)** membuat Customer Population jauh lebih
  kecil (72.78%) dari Revenue Population — interpretasi customer-level HARUS
  selalu menyebutkan bahwa ini hanya mewakili ~73% dari total transaksi
  bernilai, bukan seluruh populasi.
- **UK concentration (91.94%)** — belum ditangani di tahap ini (tidak
  relevan untuk cleaning), tapi tetap jadi catatan wajib untuk interpretasi
  Country Analysis di Tahap 12.
- **Negative-quantity-unclassified (3,457 baris)** belum diinvestigasi manual
  satu per satu — kalau ditemukan pola baru saat EDA (Tahap 7), harus balik
  ke tahap ini sesuai Dependency & Rollback Matrix, bukan diubah langsung di
  tahap analysis.
- **Whitelist non-product StockCode** didasarkan pada sample manual di
  profiling, bukan audit lengkap seluruh 5,305 distinct StockCode. Kalau
  nanti ditemukan StockCode non-product baru yang lolos whitelist, harus
  dicatat sebagai revision, bukan silent fix.

---

## 5. Revision Log

*(diisi kalau ada perubahan definisi population/treatment setelah tahap ini)*

| Tanggal | Definisi yang berubah | Alasan | Ditemukan di tahap mana |
|---|---|---|---|
| — | — | — | — |
