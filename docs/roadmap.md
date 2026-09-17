# ROADMAP — Online Retail Analytics Project (v1.0)

> 📌 **Catatan mapping file SQL yang sudah dieksekusi (v1 → v2 numbering):** roadmap ini
> menggeser nomor tahap (nambah Business Understanding & Data Collection eksplisit di depan),
> tapi file `.sql` yang sudah jalan **TIDAK di-rename/regenerate ulang** — isinya sudah sesuai
> konten tahap yang dimaksud, cuma nomor file tidak 1:1 dengan nomor tahap di dokumen ini.
>
> Kalau ada temuan baru yang perlu query tambahan di tahap yang sama, **tambahkan ke file yang
> sudah ada** (append), bukan bikin file baru dengan nomor lain. File baru hanya dibuat untuk
> tahap yang belum ada query-nya.

Workflow: **PROFILE → CLEAN → VALIDATE → EDA → MODEL → ANALYZE → MART → DASHBOARD → COMMUNICATE → QA/PUBLISH**

## Traceability Matrix (Progress Tracker)

| Tahap | File / Artifact | Status |
|---|---|---|
| 0 | `README.md`, struktur folder | ✅ |
| 1 | repository, `.gitignore`, folder structure | ✅ |
| 2 | Business Questions, Success Criteria, Analytical Scope | ✅ |
| 3 | `sql/02_data_collection.sql` | 🟡 |
| 4 | `sql/03_profiling.sql` | ✅ |
| 5 | `sql/04_analytical_population.sql` | ✅ |
| 6 | `sql/05_kpi_definition.sql` | ✅ |
| 7 | `sql/06_eda.sql` | ⬜ |
| 8 | `sql/07_modeling.sql` | ⬜ |
| 9–13 | `sql/08_business_analysis/*.sql` | ⬜ |
| 14 | `sql/09_marts.sql` | ⬜ |
| 15 | `data/data_mart/*.parquet` | ⬜ |
| 16 | `dashboard/online_retail.pbix` | ⬜ |
| 17–18 | `docs/*.md` | ⬜ |
| 19 | GitHub release, v1.0 tag | ⬜ |

*(✅ selesai · 🟡 sebagian · ⬜ belum mulai — update manual tiap ada progress)*

---

## 0. Project Skeleton

**Tujuan:** membangun struktur folder proyek terlebih dahulu, sebelum mulai bekerja di Part 1, supaya alur proyek mudah dipahami end-to-end (folder `data/`, `sql/`, `dashboard/`, `docs/`, `outputs/` sudah ada dan bernomor sesuai tahap roadmap, sebelum ada satu pun data atau query masuk).

**Aktivitas:**
- buat struktur folder dasar (`data/raw`, `data/processed`, `data/data_mart`, `db/`, `sql/00_setup` … `sql/07_marts`, `docs/`, `outputs/screenshots/`, `outputs/dashboard/`)
- tambahkan `.gitkeep` di folder kosong
- inisialisasi `README.md`, `.gitignore`
- Git checkpoint awal

**Output:**
- skeleton folder proyek (kosong, siap diisi)

**Definition of Done:**
- [ ] Semua folder di struktur skeleton sudah dibuat
- [ ] `README.md` dan `.gitignore` sudah ada
- [ ] Git checkpoint sudah di-commit

**Checkpoint:** `chore: initialize project skeleton`

---

# PART 1 — Project Foundation

## 1. Project Setup

Metode setup (struktur folder, `.gitignore`, file stub, push pertama ke GitHub) mengikuti
**`docs/project_setup_guide.md`** — tidak didefinisikan ulang di sini.

**Definition of Done:**
- [ ] Skeleton folder & file stub dibuat sesuai `project_setup_guide.md` Bagian 1
- [ ] Repository terhubung ke remote (GitHub) sesuai `project_setup_guide.md` Bagian 2
- [ ] Git checkpoint sudah di-commit

---

## 2. Business Understanding

Mencakup:
- Data Feasibility Check
- Business Questions
- Success Criteria

> Aktivitas profiling atau cleaning **tidak** masuk ke tahap ini.

### Analytical Scope

Project ini berfokus pada:
- Revenue Analytics
- Order Analytics
- Customer Analytics
- Product Analytics
- Market Analytics

Project ini TIDAK mencakup:
- Profitability Analysis (tidak ada cost/COGS)
- Forecasting
- Causal Inference
- Recommendation System
- Customer Lifetime Value prediction
- Machine Learning modeling

Seluruh analisis bersifat descriptive dan diagnostic analytics.

**Definition of Done:**
- [ ] Business Questions & Success Criteria tertulis
- [ ] Analytical Scope (IN/OUT) sudah dikunci
- [ ] Git checkpoint sudah di-commit

---

## 3. Data Collection

Mencakup:
- UCI sebagai primary source
- raw CSV sebagai source of truth
- DuckDB ingestion
- schema verification
- initial inventory
- provenance

Status: 🟡 *sebagian dieksekusi* — boleh berjalan paralel dengan Part 2 awal.

**Definition of Done:**
- [ ] Raw CSV masuk ke `data/raw/` (read-only, tidak diubah)
- [ ] Ingestion ke DuckDB berhasil, schema terverifikasi
- [ ] Git checkpoint sudah di-commit

---

## Governance & Analytical Framework

> Bagian ini adalah "lensa baca" yang berlaku di seluruh dokumen — dibaca
> sekali di sini, dipakai berulang kali di Part 3–7 tanpa perlu didefinisikan
> ulang.

### Unit of Analysis

Sebelum analisis dilakukan, unit analisis dibedakan menjadi:

**Transaction Line Level**
Grain: satu baris transaksi
Digunakan untuk: Revenue, Product analysis, Quantity analysis

**Order Level**
Grain: satu Invoice
Digunakan untuk: Orders, AOV, Basket Size

**Customer Level**
Grain: satu Customer ID
Digunakan untuk: RFM, Customer Value, Revenue Concentration

**Country Level**
Grain: satu Country
Digunakan untuk: Market analysis, Geographic comparison

Interpretasi hasil selalu mengikuti grain yang digunakan.

### Analytical Principles

Prinsip yang digunakan selama project:

1. Raw data tidak pernah diubah.
2. Semua cleaning decision harus terdokumentasi.
3. KPI harus direkonsiliasi sebelum digunakan.
4. Mean selalu didampingi median untuk metrik yang skewed.
5. Tidak ada causal claim dari data observasional.
6. Temuan harus dapat ditelusuri kembali ke data sumber.
7. Recommendation harus berasal dari evidence, bukan asumsi.

### Data Quality Governance

Urutan pengambilan keputusan:

```
Profiling → Cleaning → Validation → KPI Lock → EDA → Analysis
```

Jika ditemukan masalah fundamental setelah KPI Lock:

```
EDA Finding → Return to Cleaning → Re-validation →
KPI Reconciliation → Continue Analysis
```

Tidak diperbolehkan mengubah definisi KPI secara diam-diam.

*(Versi detail dependency & rollback per tahap ada di transisi Part 2 → Part 3, sebelum Tahap 7.)*

### Interpretation Guidelines

Beberapa metrik memerlukan interpretasi khusus:

**Customer Analysis**
Hanya berlaku untuk transaksi dengan Customer ID valid.

**Country Analysis**
Harus mempertimbangkan dominasi UK dan ketimpangan sample size.

**Revenue Analysis**
Mengukur revenue, bukan profit.

**AOV Analysis**
Mean dan median dilaporkan bersamaan karena distribusi order value cenderung skewed.

**Product Analysis**
Non-product StockCode tidak boleh diperlakukan sebagai produk fisik.

---

## Risk Register

| Risk | Dampak kalau terjadi | Mitigasi di roadmap |
|---|---|---|
| Missing Customer ID besar (~25% di dataset UCI) | Customer-level KPI bias | Dipisah jadi Customer Population di Tahap 5 |
| UK sangat dominan | Country analysis timpang | Dicatat "UK concentration" & "absolute vs relative performance" di Tahap 12 |
| Cancellation invoice bercampur di sales | Revenue overstated | Ada classification di Tahap 5 |

---

# PART 2 — Data Quality & Preparation

## 4. Data Profiling

**Tujuan:**
- memahami struktur dataset
- mengidentifikasi masalah data
- mengukur kualitas data
- menemukan anomaly yang membutuhkan investigasi lebih lanjut

**Aktivitas:**
- row count
- schema check
- missing Customer ID
- exact duplicates
- duplicate product lines
- cancellation invoices
- negative Quantity
- zero Quantity
- extreme Quantity
- zero Price
- negative Price
- extreme Price
- non-product StockCode
- country concentration
- exact cardinality

> ⚠️ Tahap ini **tidak melakukan cleaning final**. Profiling hanya menjawab: *"Apa masalah yang ada di data?"*

**Output:**
- profiling findings
- data quality summary
- anomaly inventory
- missing-value analysis
- duplicate analysis
- cancellation analysis
- price/quantity anomaly analysis
- `03_profiling_summary.parquet`

**Acceptance Criteria:**
- Semua kategori anomaly (missing, duplicate, cancellation, price/qty anomaly, non-product stockcode) sudah punya angka temuan yang terdokumentasi — bukan "sudah dicek", tapi sudah ada count/persentase-nya

**Dokumentasi:** `docs/profiling_findings.md`

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Output tersimpan di path yang benar
- [ ] `docs/profiling_findings.md` sudah diupdate
- [ ] Git checkpoint sudah di-commit

**Checkpoint:** `feat: add data profiling and dataset-specific quality findings`

---

## 5. Data Cleaning & Data Treatment

**Tujuan:** menjawab *"Setelah mengetahui masalah data, bagaimana masalah tersebut ditangani?"*

**Aktivitas:**

**Cancellation**
- classify cancellation invoice
- pisahkan sales vs cancellation/return
- validasi hubungan cancellation dengan sales

**Negative Quantity**
- investigate return / cancellation / adjustment
- tentukan retained / excluded / flagged

**Price**
- investigate Price = 0
- investigate negative Price
- investigate extreme Price

**Duplicate**
- exact duplicate handling
- business-level duplicate investigation
- hapus hanya jika ada justifikasi

**Special StockCode**
- classify physical product vs service/fee/adjustment
- flag `is_special_stockcode`

**Data Types**
- `InvoiceDate` → TIMESTAMP
- `Customer ID` → string/categorical
- create `is_cancellation`

**Analytical Population** (didefinisikan di tahap ini):

| Populasi | Cakupan | Dipakai untuk |
|---|---|---|
| Transaction / Revenue Population | data transaksi valid | Revenue, Orders, AOV, Basket, Product, Country |
| Customer Population | hanya Customer ID valid | RFM, Customer Revenue, Repeat Purchase, Customer Value |
| Return / Cancellation Population | dianalisis terpisah | analisis retur |
| Non-Product Population | diklasifikasikan | dikeluarkan hanya dari KPI yang tidak relevan |

**Output:**
- cleaned analytical dataset
- analytical populations
- cleaning decisions
- treatment flags
- `04_online_retail_clean.parquet`

**Acceptance Criteria:**
- Setiap keputusan treatment (retained/excluded/flagged) punya justifikasi tertulis; tidak ada baris yang di-drop tanpa alasan yang dicatat di `docs/assumptions_and_limitations.md`

**Dokumentasi:** `docs/assumptions_and_limitations.md`

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Output tersimpan di path yang benar
- [ ] `docs/assumptions_and_limitations.md` sudah diupdate
- [ ] Git checkpoint sudah di-commit
- [ ] Tidak ada perubahan ke definisi population tanpa dicatat sebagai revision

**Checkpoint:** `fix: classify transaction anomalies and define analytical populations`

---

## 6. Data Validation & KPI Lock

**Tujuan:** menjawab *"Apakah dataset hasil cleaning benar-benar valid dan apakah KPI yang digunakan sudah konsisten?"*

**Data Validation**

*Structural Validation*
- row count before vs after treatment
- distinct Invoice reconciliation
- distinct StockCode reconciliation
- distinct Customer ID reconciliation
- null/missing reconciliation

*Business Validation*
- sales population
- cancellation population
- customer population
- non-product classification

**Revenue Validation**
```
Line Revenue  = Quantity × Price
Order Revenue = SUM(Line Revenue)
Total Revenue = SUM(Order Revenue)

Reconciliation: SUM(Order Revenue) ≈ SUM(Line Revenue)
```

**Order Validation**
```
Orders = COUNT(DISTINCT Invoice)
```
Dihitung dari valid sales population, bukan raw population.

**AOV Validation**
```
AOV = Revenue / Orders
```

**Basket Validation**
```
Basket Size = Total Quantity / Orders
```

**KPI Definition Lock** — setelah validation, kunci definisi:
- Revenue definition
- Order definition
- AOV definition
- Basket Size definition
- customer metric definitions

**Revision Log** (diisi kalau definisi KPI/population berubah setelah lock):

| Tanggal | Definisi yang berubah | Alasan | Ditemukan di tahap mana |
|---|---|---|---|
| — | — | — | — |

**Output:**
- validation report
- pass/fail rules
- validated analytical dataset
- final KPI definitions
- `05_validation_summary.parquet`

**Acceptance Criteria:**
- Row-count & revenue reconciliation harus 100% match (bukan sampling); kalau tidak match, treatment di Tahap 5 dianggap gagal dan harus direvisi

**Dokumentasi:** `docs/methodology.md`

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Output tersimpan di path yang benar
- [ ] `docs/methodology.md` sudah diupdate
- [ ] Git checkpoint sudah di-commit
- [ ] Tidak ada perubahan ke definisi KPI tanpa dicatat sebagai revision di Revision Log

**Checkpoint:** `feat: validate analytical dataset and lock KPI definitions`

> 🔒 **IMPORTANT:** Setelah Tahap 6, analytical population + KPI sudah **LOCKED**. Tahap berikutnya tidak boleh mengubah definisi tersebut tanpa documented revision (lihat Revision Log di atas).

---

## Dependency & Rollback Matrix

Kalau masalah baru ditemukan setelah Tahap 6 (KPI locked), begini alurnya per sumber temuan:

| Kalau masalah baru ditemukan di... | Harus balik ke tahap... | Yang wajib diulang |
|---|---|---|
| EDA (7) | Tahap 5 (Cleaning) | Re-validation (6) → EDA ulang (7) |
| Data Modeling (8) | Tahap 5 atau 6 | Re-validation (6) → Modeling ulang (8) |
| Business Analysis (9–13) | Tahap 6 (kalau soal definisi KPI) atau Tahap 5 (kalau soal data) | Tergantung sumber masalah |
| BI Layer / Mart (14–16) | Tahap terkait analysis (9–13) | Re-export mart → re-validate dashboard |
| Final QA (19) | Tahap manapun yang gagal QA | Re-run tahap terkait + re-validate |

> Begitu KPI/population di-lock di Tahap 6, **tidak ada tahap setelahnya yang
> boleh mengubah definisi tersebut secara langsung**. Semua perubahan definisi
> harus melalui jalur: `Finding → kembali ke Tahap 5/6 → dicatat sebagai
> documented revision di Revision Log → re-validate → lanjut lagi dari titik
> yang terdampak`.

**Definition of Ready — Part 3 (EDA):**
- Tahap 6 (Validation & KPI Lock) sudah 100% Done
- File `05_validation_summary.parquet` sudah tersedia
- Tidak ada open issue dari Tahap 6 yang belum diputuskan

---

# PART 3 — Exploratory Data Analysis

## 7. Exploratory Data Analysis (EDA)

**Tujuan:** memahami pola utama dataset setelah data dibersihkan dan divalidasi — **bukan** membuat dashboard.

**Revenue Exploration**
- revenue distribution
- revenue by month
- revenue by quarter
- revenue concentration
- revenue trend

**Order Exploration**
- order distribution
- order revenue distribution
- basket size distribution
- items per order

**AOV Exploration**
- mean, median, P25, P75, P90, P95, P99
- skewness
- high-AOV orders

**Customer Exploration**
- customer distribution
- order frequency
- one-time vs repeat
- customer revenue concentration

**Product Exploration**
- product distribution
- product revenue concentration
- product volume distribution
- long-tail behavior

**Country Exploration**
- country revenue
- country orders
- country customer distribution
- UK concentration
- small-market behavior

**Time Exploration**
- monthly pattern
- quarterly pattern
- day-of-week
- hour
- seasonality

**Outlier Exploration**
- high-value orders
- extreme quantity
- extreme price
- extreme customer value

**Output:**
- EDA findings
- distributions
- initial hypotheses
- candidate areas for deeper analysis

**Acceptance Criteria:**
- Semua 8 kategori exploration (Revenue, Order, AOV, Customer, Product, Country, Time, Outlier) sudah punya minimal satu finding + satu hipotesis kandidat untuk business analysis

### EDA Governance

EDA digunakan untuk memahami pola data dan menghasilkan hipotesis.

EDA tidak digunakan untuk:
- mengubah definisi KPI
- mengubah analytical population
- menghapus data tanpa justifikasi
- membuat kesimpulan kausal

Jika ditemukan masalah data baru:

```
EDA Finding
→ kembali ke Tahap 5 (Data Cleaning & Data Treatment)
→ Tahap 6 (Re-Validation)
→ ulangi EDA
```

Semua perubahan wajib terdokumentasi.

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Output tersimpan di path yang benar
- [ ] Tidak ada perubahan diam-diam ke KPI/population (lihat EDA Governance)
- [ ] Git checkpoint sudah di-commit

**Checkpoint:** `feat: add exploratory data analysis`

---

# PART 4 — Data Modeling

## 8. Data Modeling

**Dimensions:**
- Dim_Product
- Dim_Customer
- Dim_Country
- Dim_Date

**Facts:**
- Fact_Order_Lines
- Fact_Orders

**Grain:**
- `Fact_Order_Lines` — one retained transaction line
- `Fact_Orders` — one Invoice

> Modeling **tidak** mengubah analytical population. Model hanya merepresentasikan dataset yang sudah Profiled → Cleaned → Validated → KPI Locked.

**Acceptance Criteria:**
- Row count Fact = row count analytical population hasil Tahap 6 (reconciliation check ulang, bukan asumsi)

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Semua Dim/Fact table sudah dibuat sesuai grain yang didefinisikan
- [ ] Git checkpoint sudah di-commit

---

**Definition of Ready — Part 5 (Business Analysis):**
- Tahap 8 (Data Modeling) sudah 100% Done
- Fact/Dim table sudah reconcile terhadap analytical population Tahap 6
- Star schema siap dipakai (tidak ada perubahan grain yang belum final)

---

# PART 5 — Business Analysis

> **Acceptance Criteria umum Part 5:** setiap analisis di Tahap 9–13 harus
> reconcile ke Total Revenue/Orders yang dikunci di Tahap 6 — kalau breakdown
> per dimensi tidak sama dengan total locked KPI, analisis tersebut dianggap
> gagal dan harus ditelusuri ulang.

## 9. Revenue & Order Decomposition

```
Revenue = Orders × AOV
```

Analisis:
- Revenue trend
- Orders trend
- AOV trend
- Customers
- Basket Size
- volume-driven vs value-driven change
- seasonal pattern

**Definition of Done:**
- [ ] Breakdown revenue/orders reconcile ke total locked KPI (Tahap 6)
- [ ] Git checkpoint sudah di-commit

---

## 10. Understanding Order Value

```
AOV ≈ Basket Size × Average Item Value
```

Analisis:
- items/order
- distinct products/order
- average selling price
- product mix
- AOV distribution
- high-AOV orders

**Definition of Done:**
- [ ] Breakdown AOV reconcile ke total locked KPI (Tahap 6)
- [ ] Git checkpoint sudah di-commit

---

## 11. Customer Segmentation

Tetap: **Customer ID valid only**

- RFM
- actual distribution-based thresholds
- segment reconciliation
- one-time vs repeat
- customer revenue concentration

**Definition of Done:**
- [ ] Segment reconcile ke Customer Population (Tahap 5)
- [ ] Git checkpoint sudah di-commit

---

## 12. Product & Country Performance

**Product:**
- Revenue
- Quantity
- Orders containing product
- Customers
- ASP
- product concentration
- high-AOV product presence

**Country:**
- Revenue
- Orders
- Customers
- AOV
- absolute vs relative performance
- volume vs AOV matrix

**Definition of Done:**
- [ ] Breakdown product & country reconcile ke total locked KPI (Tahap 6)
- [ ] Git checkpoint sudah di-commit

---

## 13. AOV Drivers & Revenue Decomposition

**Candidate dimensions:**
- basket size
- average item value
- customer segment
- purchase frequency
- product mix
- country
- month/period

**Methods:**
- grouped comparison
- distributions
- percentiles
- contribution
- correlation
- optional descriptive regression

### Causal Interpretation Boundaries

Seluruh analisis bersifat observasional.

Project ini bertujuan menjelaskan:
- what happened
- where it happened
- who contributed
- what factors are associated

Project ini tidak bertujuan membuktikan:
- causality
- experimentation results
- uplift effect
- business impact certainty

Gunakan istilah:
- ✓ associated with
- ✓ correlated with
- ✓ tends to occur with

Hindari:
- ✗ caused by
- ✗ resulted in
- ✗ led to
- ✗ proved that

**Definition of Done:**
- [ ] Breakdown AOV drivers reconcile ke total locked KPI (Tahap 6)
- [ ] Tidak ada bahasa kausal di finding (lihat Causal Interpretation Boundaries)
- [ ] Git checkpoint sudah di-commit

---

# PART 6 — BI Layer

## 14. Data Mart Design

Marts:
- `mart_revenue_daily`
- `mart_aov_monthly`
- `mart_basket_aov`
- `mart_customer_value`
- `mart_product_performance`
- `mart_country_performance`
- `mart_data_quality_summary`

> Dashboard mart hanya mengonsumsi hasil analysis. Jangan membuat definisi populasi baru di sini.

**Acceptance Criteria:**
- Setiap mart harus lolos row-count & sum-check terhadap sumbernya (hasil Part 5) sebelum dipakai dashboard

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi untuk semua mart
- [ ] Git checkpoint sudah di-commit

---

## 15. Parquet Export

- Staging → `data/processed/`
- Final BI layer → `data/data_mart/`

**Definition of Done:**
- [ ] Semua mart ter-export ke `data/data_mart/` dalam format Parquet
- [ ] Git checkpoint sudah di-commit

---

### Dashboard Design Principles

Setiap halaman harus mengikuti urutan:
1. KPI Summary
2. Trend / Distribution
3. Root Cause Exploration
4. Business Interpretation

Visual dipilih berdasarkan kebutuhan analisis, bukan untuk memaksimalkan jumlah chart.

Setiap KPI pada dashboard harus dapat ditelusuri kembali ke:

```
Data Mart
→ Fact Table
→ Analytical Dataset
→ Raw Data
```

## 16. Visualization & Dashboard Development

**5 halaman:**
1. Revenue Overview
2. Order Value & Basket Behavior
3. Customer Value & Purchasing Behavior
4. Product & Market Performance
5. Data Quality & Methodology

**Narrative flow:**
```
Revenue → Orders & AOV → Basket → Customers → Products & Markets → Data Quality
```

**Insight communication:**
```
Finding → Evidence → Business Meaning → Action
```

**Acceptance Criteria:**
- Setiap halaman mengikuti urutan di Dashboard Design Principles, dan setiap KPI card bisa ditelusuri balik ke raw data lewat traceability chain di atas

**Definition of Done:**
- [ ] Acceptance Criteria terpenuhi
- [ ] Semua 5 halaman sudah dibuat sesuai narrative flow
- [ ] Git checkpoint sudah di-commit

---

**Definition of Ready — Part 7 (Communication & Delivery):**
- Tahap 16 (Dashboard) sudah 100% Done
- Semua KPI card sudah tervalidasi (traceable ke raw data)
- Tidak ada open issue dari BI Layer yang belum diputuskan

---

# PART 7 — Communication & Delivery

## 17. Insight & Recommendation

Gunakan hanya *actual findings*:
```
Finding → Evidence → Business Impact → Recommendation
```

> Tidak ada expected finding. Tidak ada recommendation yang ditentukan sebelum analisis selesai.

**Definition of Done:**
- [ ] Setiap insight punya evidence yang bisa ditelusuri
- [ ] Setiap recommendation punya dasar analisis (bukan asumsi)
- [ ] Git checkpoint sudah di-commit

---

## 18. Documentation

**Documents:**
- `methodology.md`
- `assumptions_and_limitations.md`
- `data_dictionary.md`
- `profiling_findings.md`
- `business_recommendations.md`

**Limitations yang tetap didokumentasikan:**
- missing Customer ID
- cancellation/return
- non-product StockCode
- extreme Quantity/Price
- duplicates
- UK concentration
- observational relationships (bukan causal)

**Definition of Done:**
- [ ] Semua 5 dokumen di atas sudah lengkap
- [ ] Semua limitation di atas terdokumentasi
- [ ] Git checkpoint sudah di-commit

---

## 19. Final Validation & Publishing

> Setiap poin di bawah ini adalah **kriteria pass/fail**, bukan sekadar
> to-do list — tahap ini dianggap selesai hanya kalau seluruh poin
> bernilai ✅.

**Data QA**
- raw preserved
- cleaning decisions documented
- analytical population validated
- duplicate treatment validated
- missing Customer ID documented

**KPI QA**
- Revenue reconciliation
- Order reconciliation
- AOV validation
- customer metric validation

**Analytical QA**
- mean vs median
- outlier treatment
- UK imbalance
- customer population
- no causal overclaim

**Dashboard QA**
- KPI cards reconcile
- filters work
- percentages correct
- definitions visible
- insights traceable to analysis

### Portfolio QA Checklist

Sebelum publishing:
- README dapat dipahami tanpa membuka Power BI
- Semua angka dashboard dapat direproduksi dari SQL
- Semua insight memiliki evidence
- Semua recommendation memiliki dasar analisis
- Semua limitation terdokumentasi
- Repository dapat dijalankan ulang dari raw data

**Publishing**
- README final
- reproduce instructions
- screenshots
- GitHub release
- v1.0 tag
- portfolio publication

**Definition of Done:**
- [ ] Semua checklist di atas (Data/KPI/Analytical/Dashboard/Portfolio QA) bernilai ✅
- [ ] Repository sudah di-tag v1.0 dan di-publish

---

# Ringkasan Perubahan dari Roadmap Sebelumnya

| Lama | Baru |
|---|---|
| Tahap 3 | → **Data Profiling** (eksplisit) |
| Tahap 4 | → **Data Cleaning & Data Treatment** |
| Tahap 5 | → **Data Validation & KPI Definition Lock** |
| *(baru)* | → **Tahap 7: Exploratory Data Analysis (EDA)** |
| Tahap 6 lama | → Tahap 8 (Data Modeling) |
| Tahap 7–11 lama | → Tahap 9–13 |
| Tahap 12–14 lama | → Tahap 14–16 |
| Tahap 15–17 lama | → Tahap 17–19 |

Pemisahan kunci:
- **EDA** dipisahkan tegas dari **Business Analysis**
- **Data Validation** (Tahap 6) dipisahkan tegas dari **Final Validation** (Tahap 19)

**Upgrade governance (v1.0):**
- Traceability Matrix, Acceptance Criteria, dan Definition of Done ditambahkan di setiap tahap
- Dependency & Rollback Matrix, Revision Log, dan Definition of Ready ditambahkan di titik-titik transisi antar Part
- Analytical Scope, Unit of Analysis, Analytical Principles, Data Quality Governance, dan Interpretation Guidelines dikonsolidasikan di penutup Part 1
- EDA Governance, Causal Interpretation Boundaries, Dashboard Design Principles, dan Portfolio QA Checklist memperkuat governance di Tahap 7, 13, 16, dan 19
