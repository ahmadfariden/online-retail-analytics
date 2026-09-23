# Business Recommendations — Online Retail Analytics

> Tahap 17 — Insight & Recommendation
> Format: Finding → Evidence → Business Impact → Recommendation
> Sumber: seluruh dokumen findings Tahap 9-13 (Part 5 — Business Analysis)

> ⚠️ Semua Finding & Business Impact di bawah ini bersifat **observasional**
> (asosiasi pada data historis 2009-2011), bukan prediksi atau klaim
> sebab-akibat. Setiap Recommendation didasarkan pada pola yang benar-benar
> ditemukan di data — tidak ada recommendation yang dibuat sebelum analisis
> selesai.

---

## Insight 1 — Konsentrasi Revenue Ekstrem di Segmen Champions

**Finding:** Hanya 10.98% customer (segmen Champions) menyumbang 53.74–53.82% dari total Customer Revenue.

**Evidence:** `customer_segmentation_findings.md` §3 — 643-648 customer (bervariasi tipis antar-run karena tie-breaking NTILE) dengan avg frequency 24.3-24.5 order dan avg monetary $14,163-14,265, dibandingkan segmen lain yang jauh di bawah itu. Divalidasi silang dengan EDA (`eda_findings.md` §4: top 20% customer = 77.17% revenue).

**Business Impact:** Ketergantungan revenue pada kelompok customer yang sangat kecil ini membuat bisnis rentan terhadap churn dari segelintir akun bernilai tinggi — kehilangan beberapa customer Champions saja berpotensi berdampak signifikan ke total revenue.

**Recommendation:** Pertimbangkan program retensi/relationship-management khusus untuk segmen Champions (bukan program retensi generik untuk semua customer), dan pantau health metric (recency, frequency) segmen ini secara berkala karena kontribusinya terhadap total revenue tidak proporsional dengan jumlah orangnya.

---

## Insight 2 — Segmen At Risk Menyimpan Revenue Historis Besar yang Berisiko Hilang

**Finding:** 620-679 customer (10.9-11.6%) tergolong "At Risk" — historically bernilai tinggi (avg monetary $3,166-3,186, avg frequency 7.2-7.6x) tapi rata-rata sudah 253-259 hari tidak order.

**Evidence:** `customer_segmentation_findings.md` §4 — segmen ini menyumbang $1.98-2.15 juta (12-12.6%) revenue historis.

**Business Impact:** Ini kandidat customer yang paling berpotensi diselamatkan lewat reaktivasi — mereka sudah terbukti bernilai tinggi di masa lalu, berbeda dengan segmen "Lost/Hibernating" yang order-nya cuma sekali dan sudah sangat lama (>500 hari).

**Recommendation:** Prioritaskan kampanye reaktivasi (misal penawaran khusus atau follow-up personal) ke segmen At Risk terlebih dahulu, bukan ke seluruh customer inactive secara merata, karena rasio potential-value-recovered per effort lebih tinggi di segmen ini.

---

## Insight 3 — Pertumbuhan Revenue 2011 Bersifat Value-Driven, Bukan Volume-Driven

**Finding:** Revenue 2011 naik tipis (+1.02%) dibanding 2010, tapi Orders justru turun 8.38% sementara AOV naik 10.27% — dan 94% dari kenaikan AOV itu berasosiasi dengan Average Item Value, hanya 5.4% dari Basket Size.

**Evidence:** `revenue_order_decomposition_findings.md` §1, `order_value_findings.md` §1 (exact decomposition: Item Value Effect $43.84 dari total ΔAOV $46.62).

**Business Impact:** Volume transaksi sebenarnya menyusut di 2011 — pertumbuhan revenue yang terlihat flat itu menutupi tren order yang sedang menurun. Kalau tren ini berlanjut tanpa upaya akuisisi/retensi order baru, revenue jangka panjang berisiko tertekan begitu kenaikan harga rata-rata per unit tidak bisa terus mengkompensasi.

**Recommendation:** Investigasi lebih lanjut penyebab penurunan jumlah order tahun 2011 (di luar cakupan analisis project ini) sebelum mengasumsikan bisnis sedang tumbuh sehat hanya berdasarkan angka revenue. Kandidat penyebab kenaikan Average Item Value juga belum teridentifikasi (bukan dari furniture, lihat Insight 6) — perlu audit harga per kategori produk lebih granular.

---

## Insight 4 — Lonjakan Musiman Q4 Konsisten dan Volume-Driven

**Finding:** Puncak revenue September-November terjadi konsisten di 2010 dan 2011, dan lonjakan November spesifiknya selalu volume-driven (jumlah order naik tajam) di kedua tahun, bukan karena AOV naik.

**Evidence:** `revenue_order_decomposition_findings.md` §2-3 — Volume Effect November 2010 ($245,653) dan 2011 ($405,713) jauh lebih besar dari AOV Effect di bulan yang sama.

**Business Impact:** Pola ini bisa diandalkan untuk perencanaan operasional musiman (stok, staffing, kapasitas logistik) karena berulang 2 tahun berturut-turut, bukan kebetulan satu tahun.

**Recommendation:** Alokasikan sumber daya (inventory, marketing) untuk mengantisipasi lonjakan volume order di September-November, dengan catatan puncak mulai bergeser lebih awal di 2011 (kenaikan YoY terbesar ada di September +18.3%, bukan lagi November).

---

## Insight 5 — 10% Order Menyumbang Hampir Setengah Total Revenue

**Finding:** Order dengan AOV di atas P90 ($879.41) — cuma 10.01% dari total order — menyumbang 47.83% dari total revenue, dengan rata-rata 78.21 distinct produk per order (vs 18.00 di order normal).

**Evidence:** `order_value_findings.md` §4.

**Business Impact:** Sebagian besar revenue bergantung pada order berskala besar (kemungkinan wholesale/bulk), bukan order retail biasa. Gangguan pada segmen order besar ini (misal masalah supply untuk order multi-produk) berdampak jauh lebih besar dibanding gangguan pada order kecil.

**Recommendation:** Perlakukan order besar/multi-produk sebagai jalur operasional terpisah (prioritas fulfillment, dedicated support) mengingat kontribusinya yang tidak proporsional terhadap revenue.

---

## Insight 6 — Non-UK Bernilai Lebih Tinggi per Transaksi, Meski Kontribusi Absolut Kecil

**Finding:** Non-UK cuma 14.47% dari total revenue, tapi AOV-nya 93.20% lebih tinggi dari UK ($852.94 vs $441.47), dan AOV median-nya juga lebih tinggi (bukan cuma mean), menandakan pergeseran distribusi yang konsisten.

**Evidence:** `product_country_performance_findings.md` §2, `aov_drivers_findings.md` §1.2.

**Business Impact:** Pasar non-UK, meski kecil secara volume, punya karakteristik order yang berbeda (kemungkinan lebih banyak reseller/wholesale) — strategi yang sama untuk UK dan non-UK berpotensi kurang optimal untuk salah satu pasar.

**Recommendation:** Pertimbangkan segmentasi strategi pasar terpisah untuk non-UK (misal minimum order value berbeda, kanal komunikasi B2B), alih-alih menyamaratakan pendekatan dengan pasar UK yang jauh lebih besar volumenya tapi AOV per transaksinya lebih rendah.

---

## Insight 7 — Furniture Bukan Penyebab Kenaikan Average Item Value

**Finding:** Kategori furniture ber-ASP tinggi yang teridentifikasi di EDA justru **turun** kontribusinya dari 0.304% ke 0.263% revenue antara 2010-2011 — berlawanan dengan hipotesis awal bahwa kategori ini mendorong kenaikan Average Item Value.

**Evidence:** `order_value_findings.md` §3.

**Business Impact:** Penyebab pasti kenaikan Average Item Value 2011 belum teridentifikasi dalam analisis ini — kemungkinan bersifat broad-based (across banyak produk) daripada terkonsentrasi di satu kategori.

**Recommendation:** Sebelum mengambil keputusan pricing berdasarkan asumsi "kategori tertentu mendorong kenaikan harga", lakukan analisis ASP per kategori produk yang lebih granular (di luar cakupan project ini) untuk mengidentifikasi kategori yang benar-benar berkontribusi.

---

## Insight 8 — Kategori/Segmen/Waktu Hanya Menjelaskan Sebagian Kecil Variasi AOV

**Finding:** Customer Segment, Country, dan Month bersama-sama hanya berasosiasi dengan <1% (Segment 0.58%, Country 0.61%, Month 0.18%) dari total variasi order-level revenue. Frekuensi pembelian customer juga nyaris tidak berkorelasi dengan average order value mereka (korelasi 0.0345).

**Evidence:** `aov_drivers_findings.md` §3-4.

**Business Impact:** Strategi yang mengasumsikan "AOV tinggi karena segmen/negara/musim tertentu" berisiko keliru — sebagian besar variasi nilai order tampaknya bersifat individual/order-specific (kemungkinan wholesale vs retail), bukan dijelaskan oleh kategori customer, geografis, atau waktu.

**Recommendation:** Hindari membuat kebijakan AOV berbasis kategori luas (misal "naikkan target AOV negara X" atau "segmen Y harus AOV lebih tinggi") tanpa mempertimbangkan bahwa driver utamanya kemungkinan besar karakteristik order individual, bukan atribut kategorikal yang mudah di-generalisasi.

---

## Ringkasan Prioritas

| Prioritas | Insight | Area Tindak Lanjut |
|---|---|---|
| Tinggi | #1, #2 | Customer retention & reactivation (Champions, At Risk) |
| Tinggi | #5 | Operational handling untuk order besar/wholesale |
| Sedang | #3, #7 | Investigasi lanjutan penyebab tren volume & harga (di luar cakupan project ini) |
| Sedang | #4 | Perencanaan musiman (inventory, staffing) |
| Sedang | #6 | Strategi pasar non-UK terpisah |
| Rendah (governance) | #8 | Kehati-hatian dalam membuat kebijakan berbasis kategori |

✅ Setiap insight di atas punya evidence yang bisa ditelusuri ke dokumen findings spesifik, dan setiap recommendation didasarkan pada pola yang ditemukan di analisis — bukan asumsi. **Acceptance Criteria Tahap 17 terpenuhi.**
