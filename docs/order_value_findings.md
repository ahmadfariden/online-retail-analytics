# Order Value Findings — Online Retail Analytics

> Tahap 10 — Understanding Order Value
> Formula: `AOV = Basket Size × Average Item Value` (identity aljabar, terverifikasi exact di seluruh 25 bulan)
> Sumber: `Fact_Order_Lines` (hasil `sql/09_order_value.sql`)
> ✅ Reconciliation PASS — total exact match ke locked KPI Tahap 6

---

## 1. Jawaban Langsung atas Pertanyaan dari Tahap 9

Tahap 9 menemukan kenaikan AOV 2011 (+10.27%). Dekomposisi di tahap ini
menjawab **dari mana** kenaikan itu berasal:

| Komponen | 2010 | 2011 | Perubahan |
|---|---|---|---|
| Basket Size (qty/order) | 276.95 | 278.50 | **+0.56%** |
| Average Item Value ($/unit) | $1.6394 | $1.7978 | **+9.66%** |
| AOV | $454.05 | $500.67 | +10.27% |

**Dekomposisi ΔAOV ($46.62):**

| Efek | Nilai | % Kontribusi |
|---|---|---|
| Basket Effect | $2.53 | 5.4% |
| **Item Value Effect** | **$43.84** | **94.0%** |
| Interaction | $0.24 | 0.5% |

**Finding:** Kenaikan AOV 2011 **hampir seluruhnya (94%) berasosiasi dengan
kenaikan Average Item Value**, BUKAN dengan basket yang lebih besar. Basket
size nyaris tidak berubah (+0.56%). Ini menjawab tegas pertanyaan dari
Tahap 9: customer di 2011 tidak membeli lebih banyak barang per order —
**harga rata-rata per unit yang terjual yang naik**.

---

## 2. Nuansa Tambahan: Product Diversity Naik, Quantity per Line Turun

| Metrik | 2010 | 2011 | Perubahan |
|---|---|---|---|
| Items/Order (line entries) | 23.24 | 25.51 | +9.77% |
| Distinct Products/Order | 22.94 | 25.26 | +10.11% |
| Qty per line (basket size / items per order) | 11.92 | 10.92 | **-8.4%** |

**Finding:** Order di 2011 berisi **lebih banyak produk berbeda** per order
(diversity naik ~10%), tapi **quantity per line item justru turun** (-8.4%) —
karena basket size total (qty keseluruhan) nyaris flat. Polanya: customer
2011 cenderung membeli **variasi produk yang lebih luas dalam jumlah kecil
per produk**, bukan membeli lebih banyak dari produk yang sama.

Kombinasi "diversity naik + avg item value naik" ini konsisten dengan
kemungkinan **product mix shift ke arah produk yang lebih beragam dan
sedikit lebih mahal per unit** — meski uji spesifik di bawah menunjukkan
bukan kategori furniture yang jadi penyebabnya.

---

## 3. Product Mix Check: Bukan Furniture

Kategori ASP tinggi (furniture, teridentifikasi di EDA Tahap 7) yang
diduga jadi kandidat penjelas kenaikan Average Item Value:

| Tahun | Revenue Furniture | % dari Total Revenue | Quantity |
|---|---|---|---|
| 2010 | $28,550.12 | 0.304% | 308 |
| 2011 | $24,909.75 | 0.263% | 230 |

**Finding:** Kontribusi furniture **justru turun** (0.304% → 0.263%),
baik dari sisi revenue maupun quantity. **Furniture BUKAN penyebab**
kenaikan Average Item Value 2011 — kenaikan harga rata-rata per unit
kemungkinan bersifat **broad-based** (across banyak produk kecil-menengah)
atau berasal dari kategori lain yang belum diidentifikasi. Kandidat ini
perlu didalami lebih lanjut di Tahap 12 (Product Performance) dengan
membandingkan ASP top-N produk antar tahun secara lebih granular.

---

## 4. High-AOV Orders (>P90, >$879.41)

| Metrik | Nilai |
|---|---|
| Jumlah order | 4,145 (10.01% dari total order) |
| Revenue dari order ini | $9,397,154.60 |
| **% dari Total Revenue** | **47.83%** |
| Avg distinct products (high-AOV) | 78.21 |
| Avg distinct products (normal) | 18.00 |
| Avg quantity (normal) | 168.25 |

**Finding:** Hanya **10% order berkontribusi hampir setengah (47.83%)
total revenue** — konsentrasi yang sangat tajam, bahkan lebih ekstrem dari
temuan EDA (top 20% order = 62.23%, jadi top 10% saja sudah menyumbang
hampir 48%). Order high-AOV punya **rata-rata 78 distinct produk**, jauh di
atas order normal (18 produk) — di level order individual, **product
diversity memang berkorelasi kuat dengan AOV tinggi**, meski di level
agregat tahunan basket size tidak banyak berubah.

---

## 5. Ringkasan untuk Tahap Berikutnya

| Temuan | Implikasi |
|---|---|
| Average Item Value adalah driver utama AOV (94% kontribusi) | Tahap 13 (AOV Drivers): fokus investigasi ke price/mix, bukan basket |
| Bukan furniture yang mendorong Item Value naik | Tahap 12 (Product Performance): perlu ASP comparison granular per produk/kategori |
| High-AOV order (10%) = hampir 50% revenue, didorong product diversity | Tahap 11 (Customer Segmentation): cek apakah high-AOV order terkonsentrasi di customer tertentu (kandidat wholesale, sejalan hipotesis EDA) |

✅ Semua breakdown reconcile 100% ke Total Revenue & Orders locked Tahap 6 —
**Acceptance Criteria Tahap 10 terpenuhi.**
