# EDA Findings — Online Retail Analytics

> Tahap 7 — Exploratory Data Analysis
> Sumber: `v_revenue_population` / `v_customer_population` (KPI locked di Tahap 6)
> Rentang: 2009-12-01 s/d 2011-12-09 (⚠️ Desember 2011 **partial month**, hanya 9 hari)

> ⚠️ Semua temuan di bawah bersifat **observasional** (asosiasi/pola), bukan
> kausal. Tidak ada perubahan ke KPI/population dilakukan di tahap ini
> (EDA Governance).

---

## 1. Revenue Exploration

**Finding:**
- Distribusi order revenue sangat skewed: median $287.96, tapi P99 sudah $4,038.92
  dan max $168,469.60.
- Revenue quintile (order-level): **20% order teratas menyumbang 62.23%**
  dari total revenue.
- Pola bulanan menunjukkan puncak konsisten di **September–November**
  (kandidat: persiapan musim belanja akhir tahun/Natal), lalu turun tajam
  di Desember — TAPI Desember 2011 hanya berisi 9 hari data (partial month),
  jadi penurunannya **bukan murni tren bisnis**, melainkan artefak batas
  data. Desember 2009 & 2010 (full month) justru masih relatif tinggi.
- MoM revenue sangat volatile (swing dari -57.68% sampai +43.57%).

**Hipotesis kandidat (untuk Tahap 9 — Revenue & Order Decomposition):**
Revenue tumbuh signifikan menjelang Q4 setiap tahun, konsisten dengan pola
seasonal retail (persiapan Natal/Boxing). Perlu dianalisis lebih lanjut
apakah kenaikan ini didorong oleh **jumlah order** atau **AOV** (volume-driven
vs value-driven).

---

## 2. Order Exploration

**Finding:**
- Basket size (total quantity per order) sangat skewed: median 142 unit,
  P99 sampai 2,306 unit, max 87,167 unit.
- Items per order (distinct produk per invoice): median 15, average 24,
  tapi ada order dengan 1,109 distinct produk berbeda dalam satu invoice.

**Hipotesis kandidat (untuk Tahap 10 — Understanding Order Value):**
Sebagian kecil order dengan basket size & item count ekstrem kemungkinan
berasal dari **customer wholesale/business account**, bukan retail
individual — perlu dicek apakah order-order ini terkonsentrasi di customer
ID tertentu (lihat Customer Exploration di bawah, customer `16446` cuma 2
order tapi revenue $168k).

---

## 3. AOV Exploration

**Finding:**
- AOV mean $474.60 vs median $287.96 — **skew_indicator positif (0.13)**,
  mengonfirmasi distribusi condong ke kanan (segelintir order bernilai
  sangat besar menarik mean ke atas). P95 = $1,397, P99 = $4,038.92.
- Top 20 high-AOV orders didominasi UK, tapi ada representasi EIRE &
  Australia dengan nilai tinggi juga.

**Hipotesis kandidat (untuk Tahap 13 — AOV Drivers):**
AOV yang jauh lebih tinggi dari median konsisten dengan keberadaan segmen
wholesale/bulk-buyer di dalam data retail. Basket size dan jumlah distinct
item kemungkinan **berasosiasi** dengan AOV tinggi (bukan cuma harga per
item yang mahal) — kandidat driver utama untuk didekomposisi di Tahap 13.

---

## 4. Customer Exploration

**Finding:**
- 5,855 customer valid; revenue per customer juga sangat skewed (median $857,
  P99 $29,599, max $580,987).
- Rata-rata 6.25 order/customer, tapi median cuma 3 — ada outlier ekstrem
  (customer `14911`, EIRE, 373 order).
- **72.31% customer adalah repeat buyer** (order > 1x), hanya 27.69% one-time.
- Revenue concentration (customer-level) **lebih tajam** dari order-level:
  top 20% customer menyumbang **77.17%** dari total revenue.

**Hipotesis kandidat (untuk Tahap 11 — Customer Segmentation):**
Proporsi repeat buyer yang tinggi (72%) mengindikasikan basis customer yang
loyal atau bersifat B2B berulang, bukan one-off retail. Segmentasi RFM
kemungkinan akan menunjukkan kelompok kecil "high-value repeat customer"
yang mendominasi revenue — konsisten dengan Pareto concentration di atas.

---

## 5. Product Exploration

**Finding:**
- 4,974 distinct produk; revenue per produk juga skewed (median $1,018,
  P90 $9,431, max $330,590 — REGENCY CAKESTAND 3 TIER).
- Meski demikian, **produk #1 hanya menyumbang 1.68%** dari total revenue —
  tidak ada single dominant product.
- Product revenue concentration: **top 20% produk menyumbang 79.02%**,
  bottom 20% cuma **0.24%** — long-tail behavior yang jelas.

**Hipotesis kandidat (untuk Tahap 12 — Product Performance):**
Revenue tidak bergantung pada satu produk unggulan, melainkan portofolio
produk yang luas dengan konsentrasi di ~20% produk teratas. Strategi
inventory/promosi kemungkinan lebih efektif difokuskan ke kelompok produk
top-quintile ini, sementara long-tail (bottom 20%) berkontribusi minim ke
revenue.

---

## 6. Country Exploration

**Finding:**
- UK menyumbang **85.53%** revenue (dari 91.94% row-share di profiling —
  sedikit lebih rendah karena AOV UK justru lebih rendah dari rata-rata).
- **AOV Non-UK ($852.94) hampir 2x AOV UK ($441.47)**.
- Pola tidak biasa: **EIRE** (3 customer, 581 order → AOV $1,073) dan
  **Netherlands** (22 customer, AOV $2,533.52) — rasio order/customer dan
  AOV yang sangat tinggi mengindikasikan akun business/reseller, bukan
  retail individual biasa.

**Hipotesis kandidat (untuk Tahap 12 — Country Performance):**
Pasar non-UK, meski kontribusi revenue absolut kecil (14.47%), punya
**AOV per transaksi jauh lebih tinggi** — kemungkinan besar merepresentasikan
mayoritas B2B/wholesale buyer di luar UK, dibanding retail konsumen individu
yang lebih dominan di pasar UK. Analisis absolute vs relative performance
di Tahap 12 wajib menyoroti perbedaan ini.

---

## 7. Time Exploration

**Finding:**
- Pola bulanan (2 tahun digabung): puncak di **November** ($2.88M),
  terendah di **Februari** ($1.05M) — konsisten dengan pola ramp-up
  belanja akhir tahun.
- Pola quarter: Q4 jauh di atas quarter lain ($7.27M vs $3.78–4.62M di
  Q1–Q3).
- **Day-of-week sangat tidak biasa**: Sabtu nyaris tidak ada aktivitas
  ($9,803 dari 30 order saja — <0.05% dari total revenue), sementara
  Senin–Jumat & Minggu jauh lebih aktif. Kamis tertinggi ($4.01M).
- Hour-of-day mengikuti pola **jam kerja kantor** (aktivitas mulai jam 7,
  puncak jam 10–15, turun drastis setelah jam 17, nyaris nol setelah jam 20).

**Hipotesis kandidat (untuk EDA lanjutan / Tahap 9):**
Pola hari (Sabtu nyaris kosong) dan jam (mengikuti jam kerja kantor)
mengindikasikan bahwa bisnis ini kemungkinan besar **beroperasi sebagai
wholesale/B2B** (order diproses di jam & hari kerja), bukan toko retail
online 24/7 murni. Ini konsisten dengan temuan Customer & Country
Exploration di atas (repeat buyer tinggi, AOV non-UK tinggi, akun
terkonsentrasi seperti EIRE/Netherlands).

---

## 8. Outlier Exploration

**Finding:**
- Extreme quantity tetap didominasi transaksi yang sudah teridentifikasi di
  profiling (invoice `581483` qty 80,995; customer `13902` dari Denmark
  membeli belasan ribu unit paper product per invoice).
- Ditemukan satu baris baru yang menarik: `FLAG OF ST GEORGE CAR FLAG`,
  qty 10,200, **Price = $0.00**, Customer ID NULL — konsisten dengan
  keputusan Tahap 5 (zero price retained), tapi baris ini **mendistorsi
  basket size/quantity** meski tidak mendistorsi revenue. Dicatat sebagai
  catatan untuk Tahap 10 (Understanding Order Value) kalau basket size
  dianalisis granular.
- Extreme ASP (Average Selling Price) didominasi kategori **furniture/kabinet**
  (REGENCY MIRROR WITH SHUTTERS $150.88, VINTAGE KITCHEN CABINET, dll) —
  ini bukan data error, melainkan kategori produk yang memang bernilai
  tinggi per unit.
- Top customer by value (`18102`, UK, $580,987/145 order) dan (`16446`, UK,
  $168,472 **hanya dari 2 order**) menunjukkan dua pola berbeda: repeat
  high-frequency vs bulk single-purchase.

**Hipotesis kandidat (untuk Tahap 11 & 12):**
Outlier di dataset ini sebagian besar **legitimate business behavior**
(wholesale/furniture/high-value repeat customer), bukan data error — tidak
perlu exclusion tambahan di luar yang sudah diputuskan Tahap 5. Kategori
furniture berpotensi jadi segmen produk terpisah yang layak dianalisis
khusus di Tahap 12 (Product Performance) karena karakteristik ASP-nya jauh
berbeda dari produk gift/dekorasi pada umumnya.

---

## Ringkasan Candidate Areas untuk Business Analysis (Part 5)

| Kandidat Area | Tahap Terkait | Sumber Hipotesis |
|---|---|---|
| Volume-driven vs value-driven Q4 growth | Tahap 9 | Revenue Exploration |
| Basket size / item count sebagai AOV driver | Tahap 10, 13 | Order & AOV Exploration |
| RFM segmentation, repeat vs one-time | Tahap 11 | Customer Exploration |
| Top-quintile product focus, long-tail | Tahap 12 | Product Exploration |
| UK vs Non-UK AOV gap, indikasi B2B non-UK | Tahap 12 | Country Exploration |
| Pola hari/jam kerja → indikasi model bisnis B2B | Tahap 9 (konteks) | Time Exploration |
| Furniture sebagai segmen produk ASP tinggi | Tahap 12 | Outlier Exploration |

✅ Semua 8 kategori exploration sudah punya minimal satu finding + satu
hipotesis kandidat — **Acceptance Criteria Tahap 7 terpenuhi.**
