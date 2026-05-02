# Northeast Asian Trilateral Supply Chain Integration and Its Impact on FDI-Led Industrialisation in Uzbekistan

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
├── references_cleaned.bib   # Deduplicated BibTeX database (102 entries, incl. 5 from 2023–2026)
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
│   ├── 02_descriptive_analysis.R
│   ├── 03_rca_analysis.R    # Revealed Comparative Advantage (Balassa 1965)
│   ├── 04_trend_regression.R
│   ├── 05_chow_test.R       # Structural break test (Chow 1960)
│   ├── 06_comparative_analysis.R
│   ├── 07_visualisations.R
│   ├── 08_export_latex_tables.R
│   ├── 09_scenario_forecasting.R  # Three-scenario Manufacturing VA through 2030
│   ├── 10_triad_figures.R
│   ├── 14_new_advanced_figures.R
│   ├── 15_export_new_chapter_tables.R
│   ├── 16_fetch_academic_literature.R
│   └── panel_robustness.R   # Panel data robustness checks (plm, Hausman test)
│
├── figures/                 # All generated figures (PNG, 300 dpi)
├── data/
│   ├── raw/                 # Original unmodified data files
│   └── processed/           # Cleaned datasets (RDS + CSV)
├── output/
│   ├── tables/              # LaTeX regression tables
│   └── logs/                # R execution logs
├── policy_toolkit/          # Policy visualisation scripts
└── stata/                   # Supplementary Stata scripts (if any)
```

---

## Data Sources

| Source | Years | Variables |
|---|---|---|
| World Bank WDI | 2010–2023 | Manufacturing VA, FDI, GDP p.c., LPI, Trade Openness |
| IMF WEO April 2025 | 2024–2026 | Manufacturing VA, FDI, GDP p.c. (projections) |
| OEC / BACI | 2010–2023 | Bilateral trade by HS section, RCA computation |
| UzbekStat | 2024 | FDI origin decomposition by country |
| OEC | 2010–2023 | Economic Complexity Index (Hidalgo & Hausmann 2009) |

---

## Key Empirical Results

| Method | Finding |
|---|---|
| Chow Structural Break Test | 2017 confirmed as a structural break for manufacturing VA (F=6.937, p=0.013) |
| OLS Regression | Intermediate goods imports significant (β=2.34, p<0.05); FDI volume insignificant (β=0.002, p=0.15) |
| RCA Analysis | No new manufactured export comparative advantages established post-2017 |
| Trade Network (Betweenness) | Uzbekistan: 0.26 — conduit node, not relational producer |
| Comparative Benchmark | FDI at 2.4% of GDP vs Vietnam's 9.8% at comparable reform stage |
| Scenario Forecast | Manufacturing VA: 24–29% of GDP by 2030 depending on reform intensity |

---

## How to Reproduce

### 1. Run R scripts (requires R ≥ 4.2, packages in `scripts/00_setup.R`)
```r
source("scripts/00_setup.R")
source("scripts/01_data_cleaning.R")   # pulls WDI + appends IMF WEO projections
source("scripts/03_rca_analysis.R")
source("scripts/05_chow_test.R")
source("scripts/07_visualisations.R")
source("scripts/09_scenario_forecasting.R")
source("scripts/panel_robustness.R")
```

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

The `references_cleaned.bib` file contains 102 deduplicated entries including 5 new references from 2023–2026:
- Usmanov (2024) — GVC integration in Central Asia (*Post-Communist Economies*)
- Akramov & Tilekeyev (2024) — Agricultural value chains (*IFPRI*)
- Andreoni & Chang (2023) — Political economy of industrial policy (*CJE*)
- Rakhmatullayev et al. (2023) — Institutional constraints on FDI (*Eurasian Geography and Economics*)
- World Bank (2025) — *Uzbekistan Economic Update*

---

## License

This repository contains academic work submitted for TSUE BMI defense. All data sources are public. Scripts are reproducible under MIT License.