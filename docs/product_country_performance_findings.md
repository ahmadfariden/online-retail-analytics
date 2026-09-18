# Product & Country Performance Findings — Online Retail Analytics

> Tahap 12 — Product & Country Performance
> Sumber: `v_product_performance`, `v_country_performance` (hasil `sql/11_product_country_performance.sql`)
> ✅ Reconciliation PASS — Product & Country breakdown exact match ke locked KPI Tahap 6

---

## 1. Product Performance

### 1.1 Top Product — Peringatan Interpretasi Penting

Produk #4 by revenue, **PAPER CRAFT , LITTLE BIRDIE** ($168,469.60, 0.858%
dari total revenue), ternyata **hanya berasal dari 1 order dan 1 customer**
(`orders_containing_product = 1`, `customers = 1`). Ini adalah transaksi
bulk ekstrem yang sudah teridentifikasi sejak Profiling (Tahap 4, invoice
`581483`, qty 80,995).

**Implikasi:** Peringkat "top product by revenue" di sini **menyesatkan
kalau dibaca sebagai indikator demand pasar luas** — produk ini populer di
angka revenue semata-mata karena satu pembelian besar, bukan karena diminati
banyak customer. Bandingkan dengan produk #2 (`WHITE HANGING HEART T-LIGHT
HOLDER`, revenue $257,724.71 dari **5,371 order dan 1,490 customer**) yang
jauh lebih representatif sebagai produk populer genuine.

### 1.2 Product Concentration

| Quintile | N Produk | Revenue | % Revenue |
|---|---|---|---|
| 1 (top 20%) | 995 | $15,523,925.79 | **79.02%** |
| 5 (bottom 20%) | 994 | $46,355.19 | 0.24% |

Konsisten persis dengan EDA (Tahap 7) — validasi silang OK.

### 1.3 High-AOV Product Presence — Temuan Baru

15 StockCode dengan **>90% kemunculannya berada di order high-AOV**
(threshold locked Tahap 10, >$879.41), termasuk `84997c`, `85049g`,
`90059A`, `84030e`, dll — kode-kode ini secara pola penamaan (awalan `9xxxx`
atau `DCGS`) berbeda dari kode produk gift/dekorasi umum (`2xxxx`), dan
konsisten selalu muncul berdampingan dengan order besar.

**Finding:** Produk-produk ini adalah kandidat kuat sebagai **"marker" order
wholesale/bulk** — kemunculannya di sebuah order bisa jadi sinyal bahwa
order tersebut kemungkinan besar high-value, terlepas dari harga satuan
produknya sendiri.

---

## 2. Country Performance

### 2.1 Absolute vs Relative Performance

| Market | Revenue | % Revenue | Orders | AOV | Revenue/Customer |
|---|---|---|---|---|---|
| UK | $16,803,732.61 | 85.53% | 38,063 | $441.47 | $3,148.54 |
| Non-UK | $2,842,842.25 | 14.47% | 3,333 | **$852.94** | **$5,363.85** |

**Finding:** Non-UK secara absolut kecil, tapi secara **relatif per
transaksi maupun per customer jauh lebih bernilai** (AOV +93%, revenue/
customer +70% dibanding UK). Ini konsisten dan memperkuat semua temuan
sebelumnya (EDA, Order Value) soal karakter non-UK yang lebih wholesale.

### 2.2 Volume vs AOV Matrix (kuadran, threshold median 43 negara)

Negara-negara di kuadran **"High Volume, High AOV"** (kombinasi langka —
banyak order DAN nilai tinggi per order): **EIRE, Netherlands, Sweden,
Australia, Switzerland, Channel Islands, Denmark, Norway, Cyprus, Japan,
Greece**.

UK, Germany, France, Spain masuk **"High Volume, Low AOV"** — pasar besar
tapi per-transaksi lebih kecil (karakter retail konsumen biasa).

### 2.3 Kasus Ekstrem: EIRE & Netherlands

- **EIRE**: 3 customer saja, revenue/customer **$207,804.72**.
- **Netherlands**: 22 customer, revenue/customer **$24,989.70**.
- **Hong Kong**: revenue $13,666.45 tapi **0 customer terdaftar** (seluruh
  transaksi Customer ID NULL) — pola B2B tanpa akun customer, konsisten
  temuan Tahap 4/5.

---

## 3. Cross-Check: Champions Segment × Country (Uji Hipotesis Tahap 11)

| Country | N Champions | Revenue | Avg Revenue/Champion |
|---|---|---|---|
| United Kingdom | 582 | $7,294,711.35 | $12,533 |
| EIRE | 2 | $575,322.67 | **$287,661** |
| Netherlands | 1 | $526,751.52 | **$526,752** |
| Germany | 18 | $224,074.25 | $12,449 |
| France | 18 | $192,800.10 | $10,711 |
| Australia | 2 | $147,934.48 | $73,967 |

**Finding:** Secara **jumlah**, 90.5% Champions (582 dari 643) berasal dari
UK — ini masuk akal karena UK memang basis customer terbesar. TAPI, secara
**nilai rata-rata per customer**, Champions dari **EIRE dan Netherlands**
jauh melampaui Champions UK (EIRE $287,661/customer dan Netherlands
$526,752/customer — **hanya 1 customer** — dibanding UK $12,533/customer).

Ini mengonfirmasi dan mempertajam hipotesis dari EDA & Order Value Analysis:
segmen "Champions" itu **heterogen** — mayoritas (UK) adalah customer aktif
biasa dengan nilai tinggi karena frekuensi, sementara **segelintir customer
non-UK (EIRE, Netherlands, Australia)** adalah individual account bernilai
ekstrem yang kemungkinan besar merupakan **reseller/wholesale buyer
tunggal**, bukan pola retail konsumen pada umumnya.

---

## 4. Ringkasan untuk Tahap 13 (AOV Drivers)

| Temuan | Implikasi |
|---|---|
| Top product #4 hanya dari 1 order/1 customer | Hati-hati generalisasi "produk populer" dari revenue rank saja |
| 15 produk ber-presence >90% di order high-AOV | Kandidat dimensi "product mix" untuk AOV driver analysis |
| Non-UK: AOV +93%, revenue/customer +70% vs UK | Country sebagai kandidat dimensi kuat untuk AOV driver |
| Champions non-UK (EIRE, NL) bernilai jauh lebih ekstrem per customer | Country × Segment interaction layak diuji di Tahap 13 |

✅ Semua breakdown Product & Country reconcile 100% ke total locked KPI
Tahap 6 — **Acceptance Criteria Tahap 12 terpenuhi.**
