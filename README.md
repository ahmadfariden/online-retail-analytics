# Online Retail Analytics

Proyek portofolio **data analyst** menggunakan dataset **UCI Online Retail**
(transaksi online retailer, dominan UK). Analisis bersifat *descriptive* &
*diagnostic* — bukan predictive/ML. Stack: **SQL (DuckDB)** untuk data
processing, **Power BI** untuk dashboard.

> 📌 Status skeleton: struktur folder awal (Tahap 0). Belum ada data atau
> query yang masuk — silakan cek strukturnya dulu sebelum lanjut ke Tahap 1
> (Project Setup) di `docs/roadmap.md`.

## Analytical Scope

**Termasuk:** Revenue Analytics · Order Analytics · Customer Analytics ·
Product Analytics · Market Analytics

**Tidak termasuk:** Profitability Analysis (tidak ada cost/COGS) ·
Forecasting · Causal Inference · Recommendation System · Customer Lifetime
Value prediction · Machine Learning modeling

Roadmap lengkap (19 tahap, governance, traceability matrix, risk register)
ada di [`docs/roadmap.md`](docs/roadmap.md).

## Struktur Folder

```
online-retail-analytics/
├── data/
│   ├── raw/              # CSV mentah dari UCI, read-only, sumber kebenaran
│   ├── processed/        # hasil cleaning/staging (parquet)
│   └── data_mart/        # BI layer final, dikonsumsi Power BI
├── db/                    # file database DuckDB (di-generate ulang dari sql/)
├── sql/
│   ├── 02_data_collection.sql
│   ├── 03_profiling.sql
│   ├── 04_analytical_population.sql
│   ├── 05_kpi_definition.sql
│   ├── 06_eda.sql
│   ├── 07_modeling.sql
│   ├── 08_business_analysis/   # Tahap 9–13, satu file per sub-analisis
│   └── 09_marts.sql
├── dashboard/             # file .pbix
├── docs/                  # roadmap, methodology, data dictionary, dst.
└── outputs/
    ├── screenshots/       # screenshot dashboard untuk README/portfolio
    └── dashboard/         # export pendukung dashboard (PDF/gambar)
```

> Catatan penomoran: nomor file `sql/` **tidak 1:1** dengan nomor Tahap di
> roadmap (lihat catatan mapping di bagian atas `docs/roadmap.md`). Kalau ada
> query tambahan untuk tahap yang sama, **append** ke file yang sudah ada,
> jangan bikin file baru.

## Workflow

```
PROFILE → CLEAN → VALIDATE → EDA → MODEL → ANALYZE → MART → DASHBOARD → COMMUNICATE → QA/PUBLISH
```

## Progress

Lihat **Traceability Matrix** di `docs/roadmap.md` untuk status tiap tahap
(✅ selesai · 🟡 sebagian · ⬜ belum mulai) — update manual tiap ada progress.
