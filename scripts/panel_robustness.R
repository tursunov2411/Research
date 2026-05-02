# ============================================================
# PANEL ROBUSTNESS REGRESSION — Problem 3 fix
# Addresses the N=14 limitation by pooling comparator countries
# into a panel (N≈70+ obs) with country fixed effects.
# ============================================================

library(tidyverse)
library(plm)       # Panel data models
library(lmtest)
library(sandwich)
library(stargazer)
library(WDI)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

# ── 1. Fetch panel data for comparator group ──────────────────────────────────
countries <- c("UZ", "VN", "KZ", "GE", "ET")  # Uzbekistan, Vietnam, Kazakhstan, Georgia, Ethiopia

indicators <- c(
  mfg_va      = "NV.IND.MANF.ZS",
  fdi_pct_gdp = "BX.KLT.DINV.WD.GD.ZS",
  trade_open  = "NE.TRD.GNFS.ZS",
  gdp_pc      = "NY.GDP.PCAP.CD"
)

panel_raw <- tryCatch(
  WDI(country = countries, indicator = indicators, start = 2010, end = 2023, extra = TRUE),
  error = function(e) {
    message("WDI fetch failed, using cached data: ", e$message)
    NULL
  }
)

if (!is.null(panel_raw)) {
  write_csv(panel_raw, "data/processed/comparator_panel.csv")
} else if (file.exists("data/processed/comparator_panel.csv")) {
  panel_raw <- read_csv("data/processed/comparator_panel.csv")
} else {
  stop("No comparator panel data available. Run with internet connection first.")
}

# ── 2. Clean and construct panel ─────────────────────────────────────────────
panel <- panel_raw |>
  select(iso2c, country, year, mfg_va, fdi_pct_gdp, trade_open, gdp_pc) |>
  filter(!is.na(mfg_va), !is.na(fdi_pct_gdp), !is.na(trade_open)) |>
  mutate(
    post2017    = as.integer(year >= 2017),
    fdi_lag1    = ave(fdi_pct_gdp, iso2c, FUN = function(x) dplyr::lag(x, 1)),
    log_gdp_pc  = log(gdp_pc)
  ) |>
  filter(!is.na(fdi_lag1))

cat(sprintf("\nPanel observations: %d (countries: %d, avg years: %.1f)\n",
            nrow(panel), length(unique(panel$iso2c)),
            nrow(panel) / length(unique(panel$iso2c))))

# ── 3. Declare as panel data object ──────────────────────────────────────────
pdata <- pdata.frame(panel, index = c("iso2c", "year"))

# ── 4. Panel models ──────────────────────────────────────────────────────────

# Model A: Country fixed effects (within estimator)
m_fe <- plm(mfg_va ~ fdi_lag1 + trade_open + post2017 + log_gdp_pc,
            data = pdata, model = "within", effect = "individual")

# Model B: Two-way fixed effects (country + year)
m_twfe <- plm(mfg_va ~ fdi_lag1 + trade_open + post2017 + log_gdp_pc,
              data = pdata, model = "within", effect = "twoways")

# Model C: Uzbekistan only (original model, for comparison)
uz_only <- panel |> filter(iso2c == "UZ")
m_uz <- lm(mfg_va ~ fdi_lag1 + trade_open + post2017, data = uz_only)

# Cluster-robust standard errors (by country)
se_fe   <- sqrt(diag(vcovHC(m_fe,   type = "HC1", cluster = "group")))
se_twfe <- sqrt(diag(vcovHC(m_twfe, type = "HC1", cluster = "group")))
se_uz   <- sqrt(diag(vcovHC(m_uz,   type = "HC3")))

# ── 5. F-test: country fixed effects significant? ────────────────────────────
fe_test <- pFtest(m_fe, plm(mfg_va ~ fdi_lag1 + trade_open + post2017 + log_gdp_pc,
                             data = pdata, model = "pooling"))
cat(sprintf("\nF-test for country fixed effects: F=%.3f, p=%.4f\n",
            fe_test$statistic, fe_test$p.value))

# ── 6. Hausman test: FE vs RE (only feasible if N_groups > k_coefficients) ────
n_groups <- length(unique(panel$iso2c))
k_coeff  <- length(coef(m_fe)) + 1   # +1 for intercept

hausman_result <- if (n_groups > k_coeff) {
  m_re <- plm(mfg_va ~ fdi_lag1 + trade_open + post2017 + log_gdp_pc,
              data = pdata, model = "random")
  h <- phtest(m_fe, m_re)
  cat(sprintf("Hausman test (FE vs RE): Chi2=%.3f, p=%.4f\n", h$statistic, h$p.value))
  sprintf("%.3f", h$p.value)
} else {
  cat(sprintf("Hausman test skipped: N_groups (%d) ≤ k_coefficients (%d)\n",
              n_groups, k_coeff))
  "N/A (N_groups too small)"
}


# ── 7. Output LaTeX table ─────────────────────────────────────────────────────
stargazer(
  m_uz, m_fe, m_twfe,
  type    = "latex",
  title   = "Panel Robustness Check: Manufacturing Value Added (\\% GDP), 2010--2023",
  label   = "tab:panel_robustness",
  column.labels = c("UZ Only (N=12)", "Country FE (N$\\approx$60)", "Two-Way FE (N$\\approx$60)"),
  covariate.labels = c("FDI (t-1)", "Trade openness", "Post-2017 dummy", "Log GDP per capita"),
  dep.var.labels = "Manufacturing VA (\\% GDP)",
  se      = list(se_uz, se_fe, se_twfe),
  add.lines = list(
    c("Country FE", "No",  "Yes", "Yes"),
    c("Year FE",    "No",  "No",  "Yes"),
    c("F-test FE p-value", "--",
      sprintf("%.4f", fe_test$p.value), "--"),
    c("Hausman p-value (FE vs RE)", "--", hausman_result, "--")
  ),
  notes = "Cluster-robust SE by country (HC1). UZ-only model uses HC3. Hausman test infeasible when N_groups <= k.",
  out   = "output/tables/panel_robustness.tex"
)


# ── 8. Also run R-based Chow test as cross-verification (Problem 2) ───────────
library(strucchange)

uz_ts <- uz_only |> arrange(year) |> filter(!is.na(mfg_va))

# Using Fstats() approach — different package than original sctest()
fs <- Fstats(mfg_va ~ trend, data = uz_ts |> mutate(trend = year - 2010))
bp_year <- uz_ts$year[which(uz_ts$year == 2017)]
chow_manual <- sctest(mfg_va ~ trend,
                      type = "Chow",
                      point = which(uz_ts$year == 2017),
                      data = uz_ts |> mutate(trend = year - 2010))

verification_log <- tibble(
  Method        = c("Original (sctest, strucchange)", "F-stats approach (strucchange)"),
  F_stat        = c(round(chow_manual$statistic, 4), round(max(fs$Fstats), 4)),
  p_value       = c(round(chow_manual$p.value, 4), NA_real_),
  Breakpoint    = c(2017, uz_ts$year[which.max(fs$Fstats)])
)

write_csv(verification_log, "output/logs/r_verification.csv")
cat("\n── Chow Test Cross-Verification ────────────────────────────────\n")
print(verification_log)
cat("\nAll outputs written to output/tables/ and output/logs/\n")
