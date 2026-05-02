# Uzbekistan's Economic Integration with Northeast Asia
## Trade, FDI, and Global Value Chains — Complete Research Repository

> **TSUE BMI 2025–2026 Compliant** | Harvard Referencing | Reproducible Empirical Pipeline  
> **Thesis Title:** Northeast Asian Trilateral Supply Chain Integration and Its Impact on FDI-Led Industrialisation and GVC Embedding in Uzbekistan  
> **Institution:** Tashkent State University of Economics (TSUE), Department of World Economy and International Economic Relations  

---

## 🔬 Research Overview

This repository contains the **complete, fully reproducible research pipeline** for the above dissertation — from raw API data collection through econometric estimation, network analysis, and final TSUE-compliant PDF/DOCX compilation.

### Central Research Question
Has Northeast Asian economic engagement (China, Japan, South Korea) driven genuine industrial upgrading in Uzbekistan post-2017, or has it reinforced a pattern of shallow, captive GVC integration?

### Core Finding
Uzbekistan has achieved **backward GVC integration** (absorbing intermediate goods at scale) but has **failed to achieve commensurate forward integration** (manufactured export upgrading). This asymmetric embedding is the quantitative signature of a **captive, not relational, governance structure**. The 2017 Mirziyoyev reforms constituted a statistically confirmed structural break (Chow F = 6.937, p = 0.013), yet the trajectory of FDI composition — infrastructure-heavy Chinese capital versus marginal Japanese/Korean manufacturing investment — prevents the Flying Geese transition from occurring organically.

---

## 📁 Repository Map

```
uzbekistan_thesis/
│
├── 📄 README.md                        ← You are here
│
├── ── MASTER ORCHESTRATION ─────────────────────────────────────
├── 📜 run_all.R                        ← Single-command full pipeline runner
├── 📜 compile_report.ps1               ← PowerShell: pdflatex → bibtex → pdflatex
│
├── ── DATA COLLECTION ──────────────────────────────────────────
├── 📜 fetch_trade_data.R               ← WDI + OEC BACI bilateral trade via API
├── 📜 fetch_fdi_data.R                 ← UNCTAD FDI inflows by origin country
├── 📜 fetch_macro_data.R               ← GDP, manufacturing VA, trade openness (WB)
├── 📜 fetch_network_data.R             ← UN Comtrade + OECD TiVA for network edges
├── 📜 fetch_literature.py              ← OpenAlex API → 300+ BibTeX references
├── 📜 fetch_literature.R               ← R-based companion literature fetcher
├── 📜 fetch_wb_data.py                 ← World Bank data via Python requests
│
├── ── DATA STORAGE ─────────────────────────────────────────────
├── 📂 data/
│   ├── raw/wdi/                        ← Raw World Bank WDI CSVs + RDS
│   ├── raw/oec/                        ← Raw bilateral trade (BACI format)
│   └── processed/                      ← Cleaned panel: uzbekistan_panel.csv,
│                                          eci_data.csv, fdi_bilateral_processed.csv
│
├── ── EMPIRICAL ANALYSIS ───────────────────────────────────────
├── 📜 empirical_checks.R               ← VIF, Breusch-Pagan, Durbin-Watson tests
├── 📜 network_analysis.R               ← igraph directed trade network construction
├── 📜 network_analysis.qmd             ← Quarto doc: network methodology + results
├── 📜 process_network_data.R           ← BEC intermediate goods classification
├── 📜 analysis.qmd                     ← Main Quarto analytical document (all regressions)
├── 📜 dissertation.qmd                 ← Original dissertation Quarto source
│
├── ── FIGURE GENERATION ────────────────────────────────────────
├── 📜 generate_figures.R               ← ggplot2: all main thesis figures (fig1–fig11)
├── 📜 generate_network_figures.R       ← Network maps + trade flow diagrams (fig12–16)
├── 📂 figures/                         ← Output: all PNG figures for LaTeX inclusion
│   ├── fig1_structural_break.png       ← Chow test: manufacturing VA break at 2017
│   ├── fig2_rca_heatmap.png            ← RCA heatmap by HS section
│   ├── fig3_rca_manufacturing.png      ← Manufacturing RCA trend
│   ├── fig4_comparative_trajectory.png ← Uzbekistan vs Vietnam reform comparison
│   ├── fig5_manufacturing_forecast.png ← Scenario forecast to 2030
│   ├── fig6_scenario_dashboard.png     ← Multi-scenario dashboard
│   ├── fig7_bilateral_trade.png        ← Trade flows: UZB–CHN/JPN/KOR
│   ├── fig8_fdi_by_origin.png          ← FDI breakdown by Northeast Asian source
│   ├── fig9_intermediate_goods_share.png ← Intermediate goods import share trend
│   ├── fig10_mechanism_trajectory.png  ← Trade openness–ECI mechanism path
│   ├── fig11_growth_decomposition.png  ← Post-reform growth attribution
│   └── fig12–21_*.png                  ← Network, benchmark, WGI, SEZ, constraint figures
│
├── ── THESIS CHAPTERS (LaTeX source) ──────────────────────────
├── 📂 chapters/
│   ├── ch_literature_review.tex        ← Full thematic lit review (GVC/FDI/LLDC)
│   ├── ch_literature_review_tsue.tex   ← Auto-generated TSUE lit review (build_tsue.py)
│   ├── ch_advanced_methodology.tex     ← Research philosophy + mixed-methods design
│   ├── ch_discussion.tex               ← Synthesis: captive trap + policy logic
│   ├── ch_constraints.tex              ← Structural constraints analysis
│   ├── ch_institutional_readiness.tex  ← WGI, human capital, governance gaps
│   ├── ch_sez_analysis.tex             ← SEZ effectiveness evaluation
│   └── ch_thailand_benchmarking.tex    ← Thailand Eastern Seaboard comparison
│
├── ── THESIS COMPILATION ───────────────────────────────────────
├── 📜 report_main.tex                  ← Primary academic LaTeX thesis (full manuscript)
├── 📜 report_tsue.tex                  ← TSUE-formatted version (auto-generated)
├── 📜 build_tsue.py                    ← Python builder: injects citations, formats TSUE
├── 📜 format_thesis.py                 ← Python formatter: TSUE margin/font compliance
├── 📜 dissertation.tex                 ← Legacy LaTeX draft
│
├── ── OUTPUT TABLES ────────────────────────────────────────────
├── 📂 output/tables/
│   ├── ols_regression.tex              ← Stargazer OLS: FDI → Manufacturing VA
│   ├── ols_eci.tex                     ← Stargazer OLS: Intermediate goods → ECI
│   ├── robustness_checks.tex           ← VIF / BP / DW diagnostics table
│   └── [benchmark, WGI, SEZ tables]   ← Chapter-specific comparison tables
│
├── ── BIBLIOGRAPHY ─────────────────────────────────────────────
├── 📄 references.bib                   ← Core manual bibliography (7 foundational refs)
├── 📄 references_expanded.bib          ← Auto-fetched: 300+ Harvard-format references
│
├── ── POLICY TOOLKIT ───────────────────────────────────────────
├── 📂 policy_toolkit/
│   ├── policy_toolkit_main.tex         ← LaTeX: Applied policy document
│   ├── policy_toolkit_main.pdf         ← Compiled: ADB/OECD-style policy brief
│   ├── generate_visuals.py             ← GVC Readiness Scorecard + Sector Matrix
│   ├── figures/                        ← Radar charts, bubble charts
│   └── data/                           ← Scorecard CSVs (Excel-compatible)
│
├── ── FINAL OUTPUTS ────────────────────────────────────────────
├── 📄 report_main.pdf                  ← Defense-ready thesis PDF (90 pages)
├── 📄 report_tsue.pdf                  ← TSUE-compliant formatted PDF (20 pages)
├── 📄 dissertation_tsue_compliant.docx ← Supervisor-ready Word Document
└── 📄 formatted_thesis.docx            ← Fully formatted DOCX (python-docx)
```

---

## 🔄 How the Research Was Conducted

### Stage 1 — Data Collection
All data is collected programmatically from open APIs to ensure full reproducibility:

| Script | Source API | Data Retrieved |
|---|---|---|
| `fetch_trade_data.R` | World Bank WDI | Manufacturing VA, FDI %, Trade openness, LPI |
| `fetch_fdi_data.R` | UNCTAD / Uzbek StatCom | FDI inflows by origin (CHN/JPN/KOR) |
| `fetch_network_data.R` | OEC BACI / OECD TiVA | Bilateral HS-level trade flows |
| `fetch_literature.py` | [OpenAlex API](https://openalex.org) | 300+ peer-reviewed references → `.bib` |

### Stage 2 — Empirical Analysis

#### Structural Break (Chow Test)
Applied to manufacturing value added (% GDP) series to confirm the 2017 Mirziyoyev reforms as a statistically significant turning point:
- **Result:** F = 6.937, p = 0.013 ✓
- **Implication:** Annual manufacturing growth accelerated from +0.4 to +1.2 pp post-reform

#### Revealed Comparative Advantage (RCA)
Balassa (1965) formula applied to OEC export data across HS-2 sections:
$$RCA_{ik} = \frac{X_{ik}/X_i}{X_{wk}/X_w}$$
- Primary commodities dominate (precious metals RCA > 5)
- Manufacturing RCA improving slowly (metals ~2.5, textiles ~1.5)
- **Finding:** Export sophistication is not keeping pace with import absorption

#### OLS Regression Models
Two models estimated with HC3 heteroskedasticity-consistent standard errors:
- **Model 1:** `MfgVA ~ FDI(t-1) + TradeOpen + Post2017 + Trend`
- **Model 2:** `MfgVA ~ FDI(t-1) + FDI(t-2) + TradeOpen + Post2017 + Trend`
- **Key result:** Intermediate goods share β = 2.34 (p < 0.05); FDI itself β = 0.002 (p = 0.15, ns)

#### Robustness Checks (`empirical_checks.R`)
| Diagnostic | Model 1 | Model 2 |
|---|---|---|
| Breusch-Pagan p-value | 0.452 | 0.512 |
| Durbin-Watson stat | 1.841 | 1.905 |
| Max VIF | 2.314 | 2.845 |

All models pass heteroskedasticity, autocorrelation, and multicollinearity thresholds.

### Stage 3 — Trade Network Analysis
`network_analysis.R` + `network_analysis.qmd` constructs a **directed weighted graph**:
- **Nodes:** UZB, CHN, JPN, KOR, ROW
- **Edges:** Trade flow volume; color-coded by intermediate vs. final goods
- **Key finding:** Japan supplies ~98% intermediate goods; China plays dual role as input supplier AND commodity importer — creating a closed-loop dependency that inhibits diversified GVC embedding

### Stage 4 — Comparative Benchmarking
Uzbekistan benchmarked against Vietnam (post-2000 Doi Moi), Thailand (Eastern Seaboard), and Kazakhstan:

| Indicator | Uzbekistan | Vietnam | Thailand |
|---|---|---|---|
| FDI % GDP | ~2.5–3% | 4.5→9.8% | 3.5→6.2% |
| LPI Score | 2.6 | 2.9 | 3.4 |
| ECI Score | -0.45 | +0.23 | +0.62 |
| Manufacturing VA % | ~14% | ~16% | ~27% |

### Stage 5 — Scenario Forecasting
Three manufacturing VA scenarios to 2030 under different FDI and logistics assumptions:
- **Baseline:** Continues at post-2017 rate → ~18% GDP
- **Accelerated GVC:** Quality FDI + logistics upgrade → ~24–27% GDP
- **Stagnation:** Reform reversal → ~12% GDP

---

## 🏗️ Compilation Instructions

### Prerequisites
- **R** (≥ 4.2) with packages: `tidyverse`, `WDI`, `strucchange`, `lmtest`, `car`, `stargazer`, `igraph`
- **Python** (≥ 3.10) with packages: `pandas`, `matplotlib`, `seaborn`, `python-docx`, `requests`
- **MiKTeX** or **TeX Live** (for PDF compilation)
- **Quarto** CLI (≥ 1.4)

### One-Command Full Pipeline
```r
# In R or RStudio:
source("run_all.R")
```

This executes all stages in sequence:
1. Fetches data from APIs
2. Runs all regressions and diagnostics
3. Generates all 21 figures
4. Builds LaTeX tables
5. Compiles the PDF thesis

### Manual Step-by-Step

```bash
# 1. Collect data
Rscript fetch_trade_data.R
Rscript fetch_fdi_data.R
python fetch_literature.py

# 2. Generate figures
Rscript generate_figures.R
Rscript generate_network_figures.R

# 3. Run robustness checks
Rscript empirical_checks.R

# 4. Build TSUE-compliant LaTeX structure
python build_tsue.py

# 5. Compile PDF thesis (PowerShell)
.\compile_report.ps1

# 6. Generate Word document
quarto pandoc report_tsue.tex -o dissertation_tsue_compliant.docx

# 7. Build Applied Policy Toolkit
cd policy_toolkit && python generate_visuals.py
pdflatex policy_toolkit_main.tex
```

---

## 📑 Applied Policy Toolkit

Alongside the academic thesis, this repository includes a **standalone applied policy toolkit** (`policy_toolkit/`) designed for policymakers, IPAs, and development institutions:

| Output | Description |
|---|---|
| **GVC Readiness Scorecard** | Comparative 10-dimension framework; Uzbekistan vs. Vietnam, Thailand, Kazakhstan |
| **Sector Targeting Matrix** | Bubble chart ranking 8 sectors by value-to-weight × tech spillover × NE Asian interest |
| **Policy Trigger Framework** | Monitorable threshold system (FDI share, customs hours, CKU railway) → automatic responses |
| **Firm-Level Survey Instrument** | 9-question tool to distinguish captive vs. relational GVC governance in SEZs |
| **Navoiy Air-Cargo Policy Brief** | ADB/OECD-style brief on air-freight as LLDC industrialisation strategy |

---

## 📚 Key References

| Category | Key Works |
|---|---|
| GVC Theory | Gereffi et al. (2005), Humphrey & Schmitz (2002) |
| Flying Geese | Akamatsu (1962), Ozawa (2005) |
| Structural Break | Chow (1960) |
| RCA | Balassa (1965) |
| Economic Complexity | Hidalgo & Hausmann (2009) |
| Data | World Bank WDI (2024), OEC BACI (2024), UNCTAD (2024) |

Full bibliography: [`references_expanded.bib`](references_expanded.bib) — 300+ entries, Harvard format.

---

## 📋 TSUE Submission Checklist

| Item | Status |
|---|---|
| Title page (titul varaq) | ✅ `report_tsue.tex` |
| Annotation in Uzbek (≤300 words) | ✅ |
| Annotation in English (≤300 words) | ✅ |
| Keywords | ✅ |
| Table of Contents | ✅ Auto-generated |
| I BOB — Kirish | ✅ |
| II BOB — Adabiyotlar Sharhi | ✅ Thematic, synthesized |
| III BOB — Metodologiya | ✅ |
| IV BOB — Tahlil va Natijalar | ✅ With robustness checks |
| V BOB — Xulosa | ✅ |
| Foydalanilgan adabiyotlar ro'yxati | ✅ Harvard, `agsm` style |
| Font: Times New Roman 14pt | ✅ `mathptmx` |
| Margins: L3 R1.5 T2 B2 cm | ✅ `geometry` package |
| Line spacing: 1.5 | ✅ `setspace` |
| Figures: `N-rasm.` format | ✅ Custom caption format |
| Tables: `N-jadval` format | ✅ Custom caption format |
| Scientific supervisor review | ⬜ Attach separately |
| External review (tashqi taqriz) | ⬜ Attach separately |
| Plagiarism check report | ⬜ Attach separately |

---

## ⚠️ Important Notes

- **No fabricated references.** All citations in `references_expanded.bib` are fetched from the OpenAlex API and verified against real DOIs.
- **No fabricated results.** All regression outputs derive from real WDI/OEC data processed by R scripts in this repo.
- The `.bib` file was cleaned to remove non-ASCII characters (Greek letters, etc.) that caused LaTeX compilation failures.

---

*Research conducted: 2025–2026 | TSUE, Tashkent, Uzbekistan*