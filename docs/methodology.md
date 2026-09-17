# Methodology

> Output Tahap 6 (Data Validation & KPI Lock).

## Validation Results
- Structural validation: row count, distinct Invoice/StockCode/Customer ID
  reconciliation, null reconciliation
- Business validation: sales, cancellation, customer, non-product
  population

## KPI Definitions (LOCKED setelah Tahap 6)
- **Revenue**  = SUM(Quantity x Price), direkonsiliasi Line -> Order -> Total
- **Orders**   = COUNT(DISTINCT Invoice) dari valid sales population
- **AOV**      = Revenue / Orders
- **Basket Size** = Total Quantity / Orders

## Revision Log

| Tanggal | Definisi yang berubah | Alasan | Ditemukan di tahap mana |
|---|---|---|---|
| — | — | — | — |

> 🔒 Setelah tahap ini, tidak ada perubahan definisi KPI/population tanpa
> dicatat sebagai revision di tabel di atas.
