# Customer Segmentation Findings — Online Retail Analytics

> Tahap 11 — Customer Segmentation
> Basis: RFM dengan threshold **kuartil dari distribusi aktual data ini** (bukan skala template generik)
> Sumber: `v_customer_segment` (hasil `sql/10_customer_segmentation.sql`), Customer Population only (5,855 customer)
> ✅ Reconciliation PASS — customer count & revenue exact match ke Customer Population Tahap 5/6

---

## 1. Threshold Aktual (Transparansi — Bukan Angka Arbitrer)

| Metrik | Min | Q1 | Median (Q2) | Q3 | Max |
|---|---|---|---|---|---|
| Recency (hari sejak order terakhir) | 0 | 25 | 95 | 378 | 738 |
| Frequency (jumlah order) | 1 | 1 | 3 | 7 | 373 |
| Monetary (total revenue) | $0 | $338.43 | $857.42 | $2,240.93 | $580,987.04 |

**Catatan:** Rentang Recency sangat lebar (Q3=378 hari, hampir setahun) —
menandakan banyak customer yang sudah lama tidak order. Frequency & Monetary
juga sangat skewed (Q3 jauh dari Max) — konsisten dengan pola konsentrasi
revenue yang berulang kali ditemukan sejak EDA.

---

## 2. Segment Summary

| Segment | N Customer | % Customer | Revenue | % Revenue | Avg Recency | Avg Frequency | Avg Monetary |
|---|---|---|---|---|---|---|---|
| **Champions** | 643 | 10.98% | $9,172,704.18 | **53.74%** | 9.5 hari | 24.5 | $14,265.48 |
| Loyal | 1,355 | 23.14% | $3,869,665.03 | 22.67% | 37.9 hari | 7.7 | $2,855.84 |
| At Risk (High Value) | 679 | 11.60% | $2,149,959.52 | 12.60% | 259.0 hari | 7.2 | $3,166.36 |
| Standard | 2,227 | 38.04% | $1,568,735.98 | 9.19% | 215.4 hari | 2.1 | $704.42 |
| Lost / Hibernating | 847 | 14.47% | $275,920.20 | 1.62% | 538.1 hari | 1.0 | $325.76 |
| New / One-Time (Recent) | 104 | 1.78% | $32,554.86 | 0.19% | 13.9 hari | 1.0 | $313.03 |

**Definisi segmen (berbasis skor kuartil R/F/M aktual, skala 1-4):**
- **Champions**: R=4, F=4, M=4 (kuartil terbaik di ketiganya)
- **Loyal**: R≥3 dan F≥3 (aktif & sering, tanpa syarat M setinggi Champions)
- **At Risk**: R≤2 tapi F≥3 dan M≥3 (dulu bernilai tinggi, sekarang mulai jarang)
- **New/One-Time (Recent)**: R=4, F=1 (baru order sekali, tapi baru-baru ini)
- **Lost/Hibernating**: R=1, F=1 (order sekali, sudah sangat lama)
- **Standard**: sisanya (tidak masuk kategori ekstrem manapun)

---

## 3. Finding Utama: Konsentrasi Ekstrem di Champions

**Hanya 10.98% customer (Champions) menyumbang 53.74% dari total revenue
Customer Population.** Digabung dengan Loyal (23.14% customer, 22.67%
revenue), **34.12% customer bagian atas menyumbang 76.41% revenue** —
konsisten dengan Pareto concentration yang sudah terlihat di EDA (top 20%
customer = 77.17% revenue, quintile-based).

Rata-rata Champions ber-frekuensi **24.5 order** dan revenue **$14,265** —
jauh di atas segmen lain. Pola ini (frekuensi sangat tinggi + revenue
sangat tinggi + recency sangat rendah/aktif) **konsisten dengan hipotesis
wholesale/B2B repeat buyer** yang sudah muncul sejak EDA (Tahap 7) dan
Order Value Analysis (Tahap 10, high-AOV order dengan banyak distinct
produk).

---

## 4. Finding Kedua: At Risk Segment — Revenue Besar, Risiko Churn

**679 customer (11.6%) tergolong "At Risk"** — historically bernilai tinggi
(avg monetary $3,166, avg frequency 7.2x), tapi **rata-rata sudah 259 hari
tidak order**. Segmen ini menyumbang **$2.15 juta (12.6%) revenue historis**
yang berisiko hilang kalau tidak ada upaya reaktivasi.

---

## 5. One-Time vs Repeat & Revenue Concentration (Validasi Silang EDA)

| Metrik | Nilai | Konsisten dengan EDA (Tahap 7)? |
|---|---|---|
| One-time customer | 1,621 (27.69%) | ✅ Sama persis |
| Repeat customer | 4,234 (72.31%) | ✅ Sama persis |
| Top 20% customer → % revenue | 77.17% | ✅ Sama persis |

Validasi silang ini mengonfirmasi konsistensi angka antara EDA (flat table)
dan Customer Segmentation (star schema) — tidak ada distorsi akibat
reshape data di Tahap 8.

---

## 6. Ringkasan untuk Tahap Berikutnya

| Temuan | Implikasi |
|---|---|
| Champions (11%) = 53.74% revenue, pola mirip wholesale | Perlu dicek di Tahap 12 apakah Champions terkonsentrasi di negara/produk tertentu (non-UK? furniture?) |
| At Risk = $2.15M revenue historis berisiko churn | Kandidat prioritas retention, meski di luar cakupan analisis lanjutan roadmap ini |
| Threshold R/F/M sangat skewed (Q3 jauh dari Max) | Konsisten dengan seluruh temuan sebelumnya: mean tidak representatif tanpa median/kuartil di dataset ini |

✅ Customer count (5,855) dan total revenue reconcile 100% ke Customer
Population Tahap 5/6 — **Acceptance Criteria Tahap 11 terpenuhi.**
