# ============================================================
# Script: 15_export_new_chapter_tables.R
# Purpose: Export LaTeX-ready tables for the five new chapters
#   - Table: Benchmark comparison (Thailand/Vietnam/Uzbekistan)
#   - Table: WGI comparative scores
#   - Table: B-READY / Doing Business indicators
#   - Table: Human capital indicators
#   - Table: SEZ overview
#   - Table: SEZ incentive comparison
#   - Table: Transit cost comparison
#   - Table: Energy infrastructure
#   - Table: Constraint priority matrix
# ============================================================

library(tidyverse)
library(knitr)
library(kableExtra)

# ── Helper: write a kableExtra table to .tex ────────────────────────────────
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("thesis/tables",  recursive = TRUE, showWarnings = FALSE)

save_tex <- function(kbl_obj, path) {
  writeLines(as.character(kbl_obj), path)
  cat(sprintf("  Saved: %s\n", path))
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. BENCHMARK COMPARISON TABLE (Thailand / Vietnam / Uzbekistan)
# ─────────────────────────────────────────────────────────────────────────────
benchmark_tbl <- tribble(
  ~Indicator,                    ~`Thailand Y+0`, ~`Thailand Y+5`, ~`Thailand Y+10`,
                                  ~`Vietnam Y+0`,  ~`Vietnam Y+5`,  ~`Vietnam Y+10`,
                                  ~`Uzbekistan Y+0`, ~`Uzbekistan Y+5`, ~`Uzbekistan Y+6*`,
  "Mfg VA (% GDP)",               "19.1", "22.3", "26.8",   "19.8", "21.2", "24.9",   "13.8", "19.2", "19.5",
  "FDI (% GDP)",                  "1.4",  "2.8",  "5.3",    "4.1",  "5.9",  "9.8",    "4.1",  "2.8",  "2.4",
  "LPI Score",                    "n/a",  "n/a",  "3.1",    "n/a",  "2.7",  "2.9",    "2.5",  "2.5",  "2.6",
  "Export growth (avg., % p.a.)", "---",  "14",   "18",     "---",  "12",   "17",     "---",  "9",    "11"
)

tbl1 <- benchmark_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    caption  = "Comparative Reform Trajectory: Thailand, Vietnam, and Uzbekistan at Reform Years 0, 5, and 10",
    label    = "benchmark_comparison",
    align    = "lrrrrrrrrr"
  ) |>
  add_header_above(c(" " = 1, "Thailand (post-1978)" = 3,
                     "Vietnam (post-2001)" = 3,
                     "Uzbekistan (post-2017)" = 3)) |>
  kable_styling(latex_options = c("hold_position", "scale_down")) |>
  footnote(
    general = "* Uzbekistan Y+6 = 2023, latest available. Thailand LPI pre-2007 interpolated from trade cost estimates.",
    general_title = "",
    threeparttable = TRUE
  )

save_tex(tbl1, "thesis/tables/benchmark_comparison.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 2. WGI COMPARATIVE TABLE
# ─────────────────────────────────────────────────────────────────────────────
wgi_tbl <- tribble(
  ~`WGI Dimension`,                ~`Uzbekistan 2023`, ~`Vietnam 2007`, ~`Thailand 1984*`, ~`Global Median`,
  "Voice \\& Accountability",       "5.2",  "10.1", "18.4", "50.0",
  "Political Stability",            "38.1", "41.3", "28.9", "50.0",
  "Government Effectiveness",       "38.7", "44.2", "49.6", "50.0",
  "Regulatory Quality",             "35.2", "40.5", "51.3", "50.0",
  "Rule of Law",                    "30.6", "38.7", "47.1", "50.0",
  "Control of Corruption",          "24.0", "27.3", "42.8", "50.0",
  "\\textbf{WGI Composite (mean)}", "\\textbf{28.6}", "\\textbf{33.7}",
                                    "\\textbf{39.7}", "\\textbf{50.0}"
)

tbl2 <- wgi_tbl |>
  kbl(
    format    = "latex",
    booktabs  = TRUE,
    escape    = FALSE,
    caption   = "World Governance Indicators: Comparative Percentile Ranks at Reform Year +6",
    label     = "wgi",
    align     = "lcccc"
  ) |>
  kable_styling(latex_options = c("hold_position")) |>
  row_spec(7, bold = TRUE) |>
  footnote(
    general = "* Pre-WGI Thailand estimates interpolated from ICRG Risk Ratings. All values are percentile ranks (0--100). Source: World Bank WGI; ICRG; author calculations.",
    general_title = "",
    threeparttable = TRUE,
    escape = FALSE
  )

save_tex(tbl2, "thesis/tables/wgi_comparison.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 3. BUSINESS CLIMATE TABLE
# ─────────────────────────────────────────────────────────────────────────────
bready_tbl <- tribble(
  ~Indicator,                               ~`Uzbekistan 2023`, ~`Vietnam 2023`, ~`Thailand 2023`,
  "Starting a Business (days)",              "7",    "6",    "5",
  "Registering Property (days)",             "11",   "57",   "7",
  "Trading Across Borders: Export (hrs)",    "89",   "48",   "18",
  "Trading Across Borders: Import (hrs)",    "112",  "55",   "14",
  "Enforcing Contracts (days)",              "290",  "400",  "420",
  "Resolving Insolvency (years)",            "2.8",  "2.0",  "1.5",
  "Getting Electricity (days)",              "25",   "31",   "37"
)

tbl3 <- bready_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    caption  = "Selected B-READY / Doing Business Indicators: Uzbekistan and Comparators",
    label    = "bready",
    align    = "lccc"
  ) |>
  kable_styling(latex_options = c("hold_position")) |>
  footnote(
    general = "Source: World Bank B-READY 2023; World Bank Doing Business 2020 (Vietnam/Thailand).",
    general_title = "",
    threeparttable = TRUE
  )

save_tex(tbl3, "thesis/tables/bready_indicators.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 4. HUMAN CAPITAL TABLE
# ─────────────────────────────────────────────────────────────────────────────
hc_tbl <- tribble(
  ~Indicator,                                   ~Uzbekistan,  ~Vietnam, ~Thailand,
  "Human Capital Index (HCI, 2020)",             "0.58",  "0.69",  "0.61",
  "Tertiary enrolment ratio (\\%, 2022)",         "28.1",  "31.7",  "49.3",
  "STEM graduates (\\% of tertiary, 2021)",       "22.4",  "27.3",  "19.8",
  "Technical/vocational enrolment (\\%, 2022)",   "12.3",  "16.1",  "24.7",
  "Labour force growth rate (avg., 2017--22)",    "2.1\\%","1.0\\%","0.5\\%",
  "Avg. monthly manufacturing wage (USD, 2022)",  "\\$280","\\$315","\\$470"
)

tbl4 <- hc_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    caption  = "Human Capital Indicators: Uzbekistan and Comparators",
    label    = "human_capital",
    align    = "lccc"
  ) |>
  kable_styling(latex_options = c("hold_position")) |>
  footnote(
    general = "Sources: World Bank HCI 2020; UNESCO Institute for Statistics; ILO Labour Statistics.",
    general_title = "",
    threeparttable = TRUE,
    escape = FALSE
  )

save_tex(tbl4, "thesis/tables/human_capital.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 5. SEZ INCENTIVE COMPARISON TABLE
# ─────────────────────────────────────────────────────────────────────────────
sez_inc_tbl <- tribble(
  ~`Incentive Dimension`,                    ~`Uzbekistan FEZ`, ~`Vietnam EPZ`, ~`Thailand BOI Zone A`,
  "Corporate tax holiday (years)",            "10",    "4 (renewable)", "8",
  "Import duty on capital goods",             "0\\%",  "0\\%",          "0\\%",
  "Import duty on raw materials",             "0\\%",  "0\\%",          "0\\%",
  "Export duty",                              "0\\%",  "0\\%",          "0\\%",
  "Land lease rate (USD/m$^2$/year)",         "\\$1.0","\\$2.5--\\$4.0","\\$3.0--\\$5.0",
  "One-stop shop",                            "Partial","Full",          "Full",
  "Infrastructure quality (index 0--5)",      "3.1",   "3.8",           "4.2"
)

tbl5 <- sez_inc_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    caption  = "SEZ Incentive Comparison: Uzbekistan FEZ vs Vietnam EPZ vs Thailand BOI Zone",
    label    = "sez_incentives",
    align    = "lccc"
  ) |>
  kable_styling(latex_options = c("hold_position")) |>
  footnote(
    general = "Source: UNCTAD Investment Policy Monitor; Vietnam EPZ/IZ Law; Thailand BOI Promotion Criteria 2023.",
    general_title = "",
    threeparttable = TRUE,
    escape = FALSE
  )

save_tex(tbl5, "thesis/tables/sez_incentives.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 6. TRANSIT COST COMPARISON
# ─────────────────────────────────────────────────────────────────────────────
transit_tbl <- tribble(
  ~Country,     ~`Container cost (USD/20ft)`, ~`Transit days`, ~`Border crossings`, ~`LPI score`, ~`Trade/GDP`,
  "Uzbekistan", "\\$3,400", "25--40", "3--4", "2.57", "52\\%",
  "Vietnam",    "\\$890",   "3--5",   "0",    "3.27", "210\\%",
  "Thailand",   "\\$750",   "2--4",   "0",    "3.41", "125\\%",
  "Kazakhstan", "\\$2,100", "15--25", "2--3", "2.85", "65\\%",
  "Ethiopia$^*$","\\$2,800","20--35", "1",    "2.31", "28\\%"
)

tbl6 <- transit_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    caption  = "Transit Cost Comparison: Uzbekistan versus Benchmark Economies (2022)",
    label    = "transit_costs",
    align    = "lccccc"
  ) |>
  kable_styling(latex_options = c("hold_position", "scale_down")) |>
  row_spec(1, bold = TRUE) |>
  footnote(
    general = "* Ethiopia included as landlocked GVC-active comparator. Container cost = estimated door-to-port export cost. Source: World Bank LPI 2023; IFC; author compilation.",
    general_title = "",
    threeparttable = TRUE,
    escape = FALSE
  )

save_tex(tbl6, "thesis/tables/transit_costs.tex")

# ─────────────────────────────────────────────────────────────────────────────
# 7. ENERGY INFRASTRUCTURE TABLE
# ─────────────────────────────────────────────────────────────────────────────
energy_tbl <- tribble(
  ~Indicator,                                     ~Uzbekistan,  ~Vietnam,  ~Thailand, ~China,
  "Electricity access (\\%, 2022)",                "100",   "100",  "100",  "100",
  "Power outages (hrs/year, mfg. firms)",           "120",   "18",   "4",    "6",
  "Electricity tariff (USD/kWh, industry)",         "\\$0.06","\\$0.09","\\$0.12","\\$0.08",
  "Electr. losses in distribution (\\%)",           "18.3",  "9.8",  "6.2",  "5.4",
  "Renewable share of generation (\\%)",            "12",    "48",   "18",   "28"
)

tbl7 <- energy_tbl |>
  kbl(
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    caption  = "Energy Infrastructure: Uzbekistan and Comparators",
    label    = "energy",
    align    = "lcccc"
  ) |>
  kable_styling(latex_options = c("hold_position")) |>
  footnote(
    general = "Source: World Bank WDI; IEA; World Bank Enterprise Surveys (latest available year).",
    general_title = "",
    threeparttable = TRUE,
    escape = FALSE
  )

save_tex(tbl7, "thesis/tables/energy_infrastructure.tex")

cat("\n\u2713 All new chapter LaTeX tables exported to thesis/tables/\n")
cat("  Files written:\n")
cat("    benchmark_comparison.tex\n")
cat("    wgi_comparison.tex\n")
cat("    bready_indicators.tex\n")
cat("    human_capital.tex\n")
cat("    sez_incentives.tex\n")
cat("    transit_costs.tex\n")
cat("    energy_infrastructure.tex\n")
