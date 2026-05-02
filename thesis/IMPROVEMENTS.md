# Improvement Log

This file tracks thesis and workflow improvements as they are made.

## 2026-04-30

- Added a direct LaTeX manuscript at `thesis/main.tex`.
- Added generated LaTeX table inputs under `thesis/tables/`.
- Added `scripts/08_export_latex_tables.R` to export statistical CSV outputs into LaTeX `tabular` files.
- Added `thesis/build_latex.ps1` to compile the LaTeX manuscript when a TeX engine is installed.
- Updated the project workflow so `run_all.R` refreshes statistics, exports LaTeX tables, and detects whether PDF compilation is available.
- Verified `run_all.R`; statistics and LaTeX table export complete successfully.
- Fixed the generated Chow-test LaTeX table alignment after validation.
- Noted that no local LaTeX engine is currently installed, so PDF compilation is ready but deferred until TinyTeX, TeX Live, or MiKTeX is available.
- Added an empirical observations section to `thesis/main.tex` summarising the descriptive, regression, Chow-test, RCA, and Vietnam-comparison findings.
- Hardened LaTeX table and figure inclusion so missing generated files display placeholders instead of stopping PDF compilation.
- Embedded generated LaTeX tables directly in `thesis/main.tex` for Overleaf compatibility and removed active table-file dependencies.
- Added `thesis/figures/` as an Overleaf-ready figure folder and `thesis/sync_overleaf_assets.ps1` to refresh copied PNG assets after rerunning the analysis.
- Converted figures in `thesis/main.tex` from floating environments to fixed captioned blocks so Overleaf preserves the intended order.
- Added `scripts/09_scenario_forecasting.R` for 2024-2030 manufacturing, FDI, and ECI scenario forecasts, integrated it into `analysis.qmd` and `run_all.R`, and exported scenario summary tables for LaTeX.
- Added `scripts/10_triad_figures.R` to generate Figures 7-11 from actual public sources (OEC/BACI, World Bank WDI, and official Uzbekistan statistics) in place of scaffold data.
