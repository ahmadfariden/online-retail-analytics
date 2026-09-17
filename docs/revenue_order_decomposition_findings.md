# Revenue & Order Decomposition Findings — Online Retail Analytics

> Tahap 9 — Revenue & Order Decomposition
> Formula: `Revenue = Orders × AOV`
> Sumber: `Fact_Order_Lines` / `Fact_Orders` (hasil `sql/08_revenue_order_decomposition.sql`)
> ✅ Reconciliation PASS — total exact match ke locked KPI Tahap 6 ($19,646,574.86, 41,396 orders)

> ⚠️ Desember 2011 hanya berisi 9 hari data (partial month). Semua interpretasi
> di bawah yang menyentuh Desember 2011 WAJIB mempertimbangkan ini — penurunan
> tajam di bulan tersebut adalah **artefak batas data, bukan tren bisnis riil**.

---

## 1. Full-Year Comparison: 2010 vs 2011

| Metrik | 2010 | 2011 | Perubahan |
|---|---|---|---|
| Revenue | $9,376,152.64 | $9,472,190.18 | **+1.02%** |
| Orders | 20,650 | 18,919 | **-8.38%** |
| AOV | $454.05 | $500.67 | **+10.27%** |

**Finding:** Revenue tahunan hampir flat (+1.02%), tapi komposisinya berubah
signifikan — **Orders turun 8.38%**, sementara **AOV naik 10.27%** menutupi
penurunan volume tersebut. Pertumbuhan revenue 2011 **tergolong value-driven**
(associated dengan kenaikan AOV, bukan volume transaksi).

> Catatan penting: karena Desember 2011 partial (9 hari vs 31 hari di
> Desember 2010), angka Orders & Revenue 2011 di atas **under-counted**
> relatif terhadap tahun penuh. Gap -8.38% Orders kemungkinan sedikit
> lebih kecil (less negative) kalau Desember 2011 lengkap.

---

## 2. Month-over-Month Decomposition (Volume vs Value)

Dari 24 transisi bulan-ke-bulan (Jan 2010 – Des 2011):

| Dominant Driver | Jumlah Bulan | Proporsi |
|---|---|---|
| Volume-driven | 17 | 70.8% |
| Value-driven (AOV) | 7 | 29.2% |

**Finding:** Mayoritas fluktuasi revenue bulanan **berasosiasi lebih kuat
dengan perubahan jumlah Orders** dibanding perubahan AOV. Ini konsisten
dengan sifat bisnis retail musiman: revenue naik-turun terutama karena
lebih banyak/sedikit orang belanja, bukan karena mereka belanja lebih
mahal per transaksi.

**Kasus khusus — November (puncak musiman):**
Baik November 2010 (+$335,188) maupun November 2011 (+$348,785) sama-sama
**volume-driven** (Volume Effect jauh lebih besar dari AOV Effect di kedua
tahun). Ini memperkuat hipotesis dari EDA (Tahap 7): lonjakan Q4
**berasosiasi dengan lebih banyak order masuk**, bukan customer yang
belanja lebih besar per transaksi.

---

## 3. Seasonal Pattern — Year-over-Year (per bulan)

| Bulan | YoY % Change | Catatan |
|---|---|---|
| Januari | +9.47% | |
| Februari | -5.59% | |
| Maret | -9.44% | |
| April | -20.26% | penurunan YoY terbesar (non-Desember) |
| Mei | +14.99% | |
| Juni | +5.78% | |
| Juli | +8.72% | |
| Agustus | +7.43% | |
| **September** | **+18.30%** | kenaikan YoY terbesar |
| Oktober | +0.80% | relatif flat |
| November | +1.56% | relatif flat |
| Desember | -20.78% | ⚠️ **partial month 2011, tidak comparable** |

**Finding:** Puncak musiman Q4 (September–November) **terjadi konsisten di
kedua tahun** — mengonfirmasi hipotesis EDA bahwa ini pola berulang
(seasonal), bukan kebetulan satu tahun. Namun **magnitude puncaknya relatif
stabil YoY** di Oktober & November (+0.8% dan +1.56%), sedangkan **kenaikan
terbesar justru terjadi di September** (+18.3%) — mengindikasikan puncak
musiman mulai bergeser lebih awal di 2011 dibanding 2010.

---

## 4. Customers & Basket Size (pelengkap dekomposisi)

- `orders_per_customer` juga naik di bulan-bulan puncak (November 2010: 1.77,
  November 2011: 1.72) dibanding rata-rata bulan biasa (~1.5–1.65) — lonjakan
  November berasosiasi dengan **kombinasi customer baru + customer existing
  belanja lebih sering**, bukan cuma salah satu.
- `basket_size_mean` tidak menunjukkan pola musiman yang konsisten dengan
  Revenue/Orders — kadang naik di bulan sepi (Januari 2011: 355.18) dan
  turun di bulan puncak (November 2011: 266.44). Ini akan didalami lebih
  lanjut di Tahap 10 (Understanding Order Value).

---

## 5. Ringkasan untuk Business Analysis Lanjutan

| Temuan | Implikasi untuk Tahap Berikutnya |
|---|---|
| Growth 2011 value-driven (AOV naik, Orders turun) | Tahap 13 (AOV Drivers): apa yang mendorong kenaikan AOV 2011? |
| November selalu volume-driven, 2 tahun berturut | Kandidat kuat untuk planning inventori/marketing musiman |
| Puncak musiman bergeser ke September di 2011 | Perlu dicek juga di Tahap 12 (Country) apakah pergeseran ini merata di semua pasar atau spesifik UK |
| Basket size tidak berkorelasi jelas dengan seasonality | Tahap 10 perlu memisahkan basket size vs average item value sebagai driver AOV terpisah |

✅ Semua breakdown di atas reconcile 100% ke Total Revenue & Orders locked
Tahap 6 — **Acceptance Criteria Tahap 9 terpenuhi.**
