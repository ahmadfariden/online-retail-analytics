# AOV Drivers & Revenue Decomposition Findings — Online Retail Analytics

> Tahap 13 — AOV Drivers & Revenue Decomposition
> Sumber: `v_order_dimensions` (hasil `sql/12_aov_drivers.sql`)
> ✅ Reconciliation PASS — total exact match ke locked KPI Tahap 6

> ⚠️ **Seluruh temuan di bawah bersifat observasional.** Istilah yang
> digunakan: "berasosiasi dengan", "berkorelasi dengan", "cenderung terjadi
> bersamaan dengan". Tidak ada klaim "disebabkan oleh", "mengakibatkan",
> atau "terbukti" di dokumen ini — konsisten dengan Causal Interpretation
> Boundaries roadmap.

---

## 1. Grouped Comparison: AOV per Dimensi

### 1.1 Customer Segment

| Segment | N Order | AOV Mean | AOV Median | AOV P90 | Std Dev |
|---|---|---|---|---|---|
| Champions | 15,776 | $582.75 | $326.98 | $1,010.56 | $1,286.25 |
| At Risk | 4,760 | $429.65 | $306.96 | $772.24 | $1,346.79 |
| Loyal | 10,561 | $373.14 | $282.33 | $717.65 | $462.31 |
| Standard | 4,589 | $346.65 | $207.80 | $566.06 | **$2,550.09** |
| Lost/Hibernating | 845 | $324.13 | $221.59 | $547.15 | $632.81 |
| New/One-Time | 81 | $315.25 | $242.44 | $507.12 | $435.58 |

**Observasi:** AOV mean tertinggi berasosiasi dengan segmen Champions, sesuai
ekspektasi. Namun **AOV median antar segmen jauh lebih berdekatan** (207.80
– 326.98) dibanding AOV mean (315.25 – 582.75) — perbedaan rata-rata antar
segmen banyak dipengaruhi oleh outlier bernilai sangat besar, bukan
perbedaan sistematis di order "khas". Menariknya, segmen **Standard justru
punya std dev tertinggi** ($2,550) melebihi Champions — mengindikasikan ada
order bernilai sangat ekstrem yang muncul dari customer yang secara R/F/M
keseluruhan tergolong "biasa saja".

### 1.2 Country (UK vs Non-UK)

| Market | N Order | AOV Mean | AOV Median | AOV P90 | Std Dev |
|---|---|---|---|---|---|
| Non-UK | 3,333 | $852.94 | $421.20 | $1,505.51 | $1,867.33 |
| UK | 38,063 | $441.47 | $276.59 | $817.02 | $1,380.91 |

**Observasi:** AOV median Non-UK ($421.20) juga lebih tinggi dari UK
($276.59), bukan cuma mean — jadi perbedaan ini **bukan semata artefak
outlier**, ada pergeseran distribusi yang konsisten, tidak hanya di ekor.

### 1.3 Month

Variasi bulanan (lihat Tahap 9 untuk detail) menunjukkan AOV mean berkisar
$394–$735, dengan AOV median jauh lebih stabil ($242–$317) — pola serupa
dengan temuan segmen: variasi mean bulanan banyak dipengaruhi outlier,
bukan pergeseran sistematis pada order "khas".

---

## 2. Correlation: Order-Level Associations

| Pasangan | Koefisien Korelasi | Interpretasi |
|---|---|---|
| Order Revenue ↔ Quantity | **0.6371** | Asosiasi positif moderat — order dengan quantity lebih besar cenderung bernilai lebih tinggi |
| Order Revenue ↔ Distinct Products | 0.2687 | Asosiasi positif lemah-moderat |
| Quantity ↔ Distinct Products | 0.1105 | Asosiasi lemah — order dengan quantity besar tidak selalu berarti produk beragam |

**Observasi:** Quantity per order berasosiasi lebih kuat dengan revenue
dibanding jumlah produk berbeda per order. Ini melengkapi temuan Tahap 10
(basket effect kecil secara agregat tahunan) dengan nuansa cross-sectional:
**di level order individual, quantity tetap jadi faktor yang paling
berasosiasi dengan nilai order**, meski secara rata-rata tahunan basket
size tidak banyak bergeser.

---

## 3. Correlation: Purchase Frequency vs Average Order Value (Level Customer)

**Koefisien korelasi: 0.0345** (dari 5,855 customer) — **mendekati nol**.

**Observasi paling penting di tahap ini:** frekuensi pembelian customer
**hampir tidak berasosiasi** dengan besarnya nilai order rata-rata mereka.
Customer yang sering belanja TIDAK cenderung memiliki order yang lebih
besar atau lebih kecil dibanding customer yang jarang belanja — dua
karakteristik ini tampak **independen satu sama lain** dalam data ini.
Temuan ini mengoreksi kesan sekilas dari Tahap 11 (Champions = frequency
tinggi + monetary tinggi) — hubungan itu muncul karena definisi RFM
menggabungkan keduanya, bukan karena frequency dan average order value
saling berasosiasi secara langsung.

---

## 4. Contribution Analysis: Eta-Squared

| Dimensi | Eta-Squared | Interpretasi |
|---|---|---|
| Country (UK vs Non-UK) | **0.0061** | ~0.61% variasi order revenue berasosiasi dengan negara |
| Customer Segment | 0.0058 | ~0.58% variasi order revenue berasosiasi dengan segmen |
| Month | 0.0018 | ~0.18% variasi order revenue berasosiasi dengan bulan |

**Observasi paling signifikan di seluruh Tahap 13:** meskipun rata-rata AOV
berbeda cukup jelas antar Segment, Country, dan Month (Bagian 1), **ketiga
dimensi ini bersama-sama hanya berasosiasi dengan kurang dari 1% dari total
variasi order-level revenue**. Sebagian besar variasi revenue per order
**tidak berasosiasi dengan kategori manapun yang diuji di sini** —
mengindikasikan bahwa nilai sebuah order jauh lebih dipengaruhi oleh
karakteristik order itu sendiri (kemungkinan besar: apakah order tersebut
bersifat wholesale/bulk atau tidak, terlepas dari segmen, negara, atau
waktu pembeliannya) dibanding oleh kategori customer/geografis/waktu.

Ini konsisten dengan pola yang berulang kali muncul sejak EDA: **high-value
order tampaknya bersifat lintas-kategori** (cross-cutting) — tidak terikat
rapi pada satu segmen, satu negara, atau satu periode waktu tertentu.

---

## 5. Ringkasan Akhir Part 5 (Business Analysis)

| Temuan Kumulatif (Tahap 9-13) | Catatan |
|---|---|
| Growth 2011 value-driven (Tahap 9-10), tapi eksplorasi drivernya (segmen/negara/bulan) hanya menjelaskan <1% variasi order-level (Tahap 13) | Driver AOV yang sesungguhnya kemungkinan bersifat individual/order-specific, bukan kategorikal |
| Champions (Tahap 11) sangat menyumbang revenue, tapi frequency tidak berasosiasi dengan average order value (Tahap 13) | RFM sebagai alat segmentasi customer tetap valid, tapi tidak serta-merta menjelaskan variasi AOV |
| Non-UK & top-quintile customer/produk konsisten bernilai tinggi (Tahap 11-12) | Country tetap dimensi dengan eta-squared tertinggi di antara yang diuji, meski kecil secara absolut |

✅ Semua breakdown reconcile 100% ke total locked KPI Tahap 6, dan seluruh
narasi di atas menggunakan bahasa asosiatif/observasional — **Acceptance
Criteria Tahap 13 terpenuhi.**

---

## Penutup Part 5 — Business Analysis

Dengan selesainya Tahap 13, seluruh **Part 5 (Business Analysis)** roadmap
ini tuntas (Tahap 9–13). Temuan-temuan di bagian ini siap menjadi input untuk
**Part 6 — BI Layer** (dashboard/visualisasi) dan pelaporan akhir, dengan
catatan penting yang harus terus dibawa: mayoritas insight di project ini
bersifat asosiasi/observasional pada data historis 2009-2011, bukan
prediksi atau klaim sebab-akibat untuk pengambilan keputusan bisnis di masa
depan.
