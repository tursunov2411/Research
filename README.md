# Northeast Asian GVC Integration and Uzbekistan Industrialisation

**Bachelor's Dissertation (BMI) — Toshkent State University of Economics (TSUE/TDIU)**
**Student:** Tursunov Sunnatilla Uchqun o'g'li | Group: MO-68/22i
**Supervisor:** Zayniddinov Ruhiddin Xusniddin o'g'li, i.f.n., k.o'q.
**Date:** May 2026

---

## Overview

This repository contains the full, reproducible dissertation manuscript examining whether and through what mechanisms Northeast Asian economic engagement (China, Japan, South Korea) has driven genuine industrial upgrading in Uzbekistan following the 2017 Mirziyoyev reforms, or whether it has reinforced a pattern of primary commodity export and shallow assembly without technology transfer.

**Central finding:** Uzbekistan has achieved substantial *backward* GVC integration (absorbing intermediate goods) but has failed to achieve commensurate *forward* integration (manufactured export upgrading). This asymmetric embedding is the quantitative signature of **captive rather than relational GVC governance**.

---

## Repository Structure

```
uzbekistan_thesis/
│
├── report_main.tex          # Master LaTeX manuscript (single source of truth)
├── report_main.pdf          # Compiled PDF (latest version)
├── references_cleaned.bib   # Deduplicated BibTeX database (audited)
│
├── chapters/                # LaTeX chapter files (input into report_main.tex)
│   ├── ch_literature_review.tex
│   ├── ch_advanced_methodology.tex
│   ├── ch_thailand_benchmarking.tex
│   ├── ch_institutional_readiness.tex
│   ├── ch_sez_analysis.tex
│   ├── ch_constraints.tex
│   ├── ch_discussion.tex
│   └── tsue_forms.tex       # TSUE submission forms (pre-filled)
│
├── scripts/                 # R analysis scripts (run in order)
│   ├── 00_setup.R           # Package installation and environment setup
│   ├── 01_data_cleaning.R   # WDI pull (2010–2026) + IMF WEO 2025 projections
│   ├── 02_descriptive_analysis.R  # Descriptive stats (means, SDs, trends)
│   ├── 03_rca_analysis.R    # Revealed Comparative Advantage (Balassa 1965)
│   ├── 04_trend_regression.R     # Linear time-trend regressions
│   ├── 05_chow_test.R       # Structural break test (Chow + Bai–Perron endogenous)
│   ├── 06_comparative_analysis.R
│   ├── 07_visualisations.R  # ALL figure generation (consolidated)
│   ├── 08_export_latex_tables.R
│   ├── 09_scenario_forecasting.R  # Three-scenario Manufacturing VA through 2030
│   ├── 10_triad_figures.R
│   ├── 11_ols_regression.R  # OLS with BACI-computed intermediate goods share
│   ├── 14_new_advanced_figures.R
│   ├── 15_export_new_chapter_tables.R
│   ├── 16_fetch_academic_literature.R
│   └── panel_robustness.R   # Panel data robustness checks (plm, Hausman test)
│
├── output/
│   ├── figures/             # ALL generated figures (PNG, 300 dpi) — SINGLE SOURCE
│   ├── tables/              # LaTeX regression tables
│   └── logs/                # R execution logs
├── figures/                 # Legacy figure directory (see output/figures/)
├── data/
│   ├── raw/                 # Original unmodified data files
│   └── processed/           # Cleaned datasets (RDS + CSV)
├── policy_toolkit/          # Policy visualisation scripts
└── stata/                   # Supplementary Stata scripts (if any)
```

---

## Data Sources

| Source | Years | Variables |
|---|---|---|
| World Bank WDI | 2010–2023 | Manufacturing VA, FDI, GDP p.c., LPI, Trade Openness |
| IMF WEO October 2025 / author scenarios | 2024–2026 | Macro outlook used to calibrate scenario extensions; manufacturing VA and FDI projections are author estimates, not direct WEO series |
| OEC / BACI | 2010–2023 | Bilateral trade by HS section, RCA computation |
| UzbekStat | 2024 | FDI origin decomposition by country |
| OEC | 2010–2023 | Economic Complexity Index (Hidalgo & Hausmann 2009) |

---

## Key Empirical Results

| Method | Finding |
|---|---|
| Chow Structural Break Test | 2017 confirmed as a structural break for manufacturing VA (F=6.937, p=0.013) |
| Endogenous Breakpoint (Bai–Perron) | Data-determined break coincides with 2017, strengthening the exogenous result |
| Interaction Term | β=0.219, p=0.319 — not significant individually (see note on joint vs individual tests) |
| OLS Regression | Time trend significant (β=0.723, p<0.01); FDI volume insignificant |
| RCA Analysis | No new manufactured export comparative advantages established post-2017 |
| Trade Network (Betweenness) | Uzbekistan: 0.26 — conduit node, not relational producer |
| Comparative Benchmark | FDI at 2.4% of GDP vs Vietnam's 9.8% at comparable reform stage |
| Scenario Forecast | Manufacturing VA: 24–29% of GDP by 2030 depending on reform intensity |

---

## How to Reproduce

### 1. Run R scripts (requires R ≥ 4.2, packages in `scripts/00_setup.R`)

Run the numbered scripts in order. The full execution sequence:

```r
# Core data pipeline
source("scripts/00_setup.R")
source("scripts/01_data_cleaning.R")      # pulls WDI + appends IMF WEO projections
source("scripts/02_descriptive_analysis.R") # descriptive statistics (Table 1)
source("scripts/03_rca_analysis.R")        # Revealed Comparative Advantage
source("scripts/04_trend_regression.R")    # time-trend regressions
source("scripts/05_chow_test.R")           # structural break + endogenous search
source("scripts/06_comparative_analysis.R") # UZB vs VNM benchmarking

# Figures (consolidated — replaces root-level generate_*.R scripts)
source("scripts/07_visualisations.R")      # ALL figures → output/figures/

# Tables and additional analysis
source("scripts/08_export_latex_tables.R")
source("scripts/09_scenario_forecasting.R")
source("scripts/10_triad_figures.R")
source("scripts/11_ols_regression.R")      # OLS with BACI-computed interm_share
source("scripts/14_new_advanced_figures.R")
source("scripts/15_export_new_chapter_tables.R")

# Robustness
source("scripts/panel_robustness.R")       # panel data + Hausman test
```

If R is unavailable locally, the dependency-light Python fallback regenerates the panel and diagnostic LaTeX tables from cached CSV data:

```bash
python scripts/12_empirical_robustness.py
```

**Note:** The root-level `generate_figures.R` and `generate_network_figures.R` are retained for backward compatibility but are superseded by `scripts/07_visualisations.R`. All figures are now consolidated in `output/figures/`.

### 2. Compile the PDF
```bash
pdflatex report_main.tex
bibtex report_main
pdflatex report_main.tex
pdflatex report_main.tex
```

### 3. Generate DOCX (requires pandoc ≥ 3.0)
```bash
pandoc report_main.tex \
  --bibliography=references_cleaned.bib \
  --citeproc --from latex --to docx \
  --output report_main.docx
```

---

## Bibliography

The `references_cleaned.bib` file has been audited (2026-05-02):
- **38 irrelevant entries removed** (COVID clinical, machine learning, cancer statistics, digital twins, geology, urban planning, etc.)
- **Andreoni & Chang (2023) duplicate resolved**: `andreoni2023rp` (Research Policy) and `andreoni2023cje` (Cambridge Journal of Economics)
- **3 references added**:
  - Hausmann, Hwang & Rodrik (2007) — *What You Export Matters* (Journal of Economic Growth)
  - Taglioni & Winkler (2016) — *Making Global Value Chains Work for Development* (World Bank)
  - Harding & Javorcik (2011) — *Roll Out the Red Carpet* (Economic Journal)

---

## License

This repository contains academic work submitted for TSUE BMI defense. All data sources are public. Scripts are reproducible under MIT License.
