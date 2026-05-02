# ============================================================
# Script: 04_trend_regression.R
# Purpose: Estimate linear time-trend regressions for
#          manufacturing VA and ECI (Uzbekistan 2010–2023).
#          These are the baseline trend models referenced
#          in Section 4 and the Chow test (05_chow_test.R).
# Outputs: output/tables/table_trend_regression.tex
#          output/logs/trend_regression_log.txt
# ============================================================

source("scripts/00_setup.R")
library(stargazer)
library(sandwich)
library(lmtest)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs",   recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------
# 1. LOAD DATA
# -------------------------------------------------------

wb <- readRDS("data/processed/wb_indicators.rds")

uzb <- wb %>%
  filter(country_code == "UZB", year >= 2010, year <= 2023) %>%
  select(year, manuf_va_gdp, fdi_gdp, gdp_per_capita, lpi_score) %>%
  arrange(year)

# ECI data
eci <- tryCatch(
  readRDS("data/processed/eci_data.rds") %>%
    filter(country_code == "UZB") %>%
    select(year, eci),
  error = function(e) {
    message("ECI data not found; ECI model will be skipped.")
    NULL
  }
)

if (!is.null(eci)) {
  uzb <- uzb %>% left_join(eci, by = "year")
}

# Add time trend and reform dummy
uzb <- uzb %>%
  mutate(
    time_trend  = year - min(year),
    post_2017   = as.integer(year >= 2017)
  )

# -------------------------------------------------------
# 2. MANUFACTURING VA TREND MODELS
# -------------------------------------------------------

# Model T1: Simple linear trend
t1 <- lm(manuf_va_gdp ~ time_trend, data = uzb)

# Model T2: Linear trend + post-2017 dummy (level shift)
t2 <- lm(manuf_va_gdp ~ time_trend + post_2017, data = uzb)

# Model T3: Trend + dummy + interaction (slope change)
t3 <- lm(manuf_va_gdp ~ time_trend * post_2017, data = uzb)

cat("\n=== Manufacturing VA Trend Models ===\n")
cat("Model T1 (Trend only):\n")
print(summary(t1))
cat("\nModel T2 (Trend + Post-2017 dummy):\n")
print(summary(t2))
cat("\nModel T3 (Trend × Post-2017 interaction):\n")
print(summary(t3))

# HC3 robust standard errors
t1_hc <- coeftest(t1, vcov = vcovHC(t1, type = "HC3"))
t2_hc <- coeftest(t2, vcov = vcovHC(t2, type = "HC3"))
t3_hc <- coeftest(t3, vcov = vcovHC(t3, type = "HC3"))

# -------------------------------------------------------
# 3. ECI TREND MODELS (if data available)
# -------------------------------------------------------

eci_models <- list()
if ("eci" %in% names(uzb)) {
  uzb_eci <- uzb %>% filter(!is.na(eci))

  if (nrow(uzb_eci) >= 5) {
    # Model E1: Simple ECI trend
    e1 <- lm(eci ~ time_trend, data = uzb_eci)
    # Model E2: ECI trend + post-2017
    e2 <- lm(eci ~ time_trend + post_2017, data = uzb_eci)

    eci_models$e1 <- e1
    eci_models$e2 <- e2

    cat("\n=== ECI Trend Models ===\n")
    cat("Model E1:\n"); print(summary(e1))
    cat("Model E2:\n"); print(summary(e2))
  }
}

# -------------------------------------------------------
# 4. ANNUALISED GROWTH RATES
# -------------------------------------------------------

# Pre-2017 vs Post-2017 slope comparison
pre_trend  <- lm(manuf_va_gdp ~ time_trend, data = filter(uzb, year < 2017))
post_trend <- lm(manuf_va_gdp ~ time_trend, data = filter(uzb, year >= 2017))

cat("\n=== Pre-2017 Annual Growth ===\n")
cat("Slope:", round(coef(pre_trend)["time_trend"], 4), "pp/year\n")
cat("\n=== Post-2017 Annual Growth ===\n")
cat("Slope:", round(coef(post_trend)["time_trend"], 4), "pp/year\n")
cat("Acceleration factor:",
    round(coef(post_trend)["time_trend"] / coef(pre_trend)["time_trend"], 2),
    "x\n")

# -------------------------------------------------------
# 5. EXPORT RESULTS
# -------------------------------------------------------

# LaTeX table
model_list <- list(t1, t2, t3)
col_labels <- c("(T1) Trend", "(T2) + Dummy", "(T3) + Interaction")

if (length(eci_models) > 0) {
  model_list <- c(model_list, eci_models)
  col_labels <- c(col_labels, "(E1) ECI Trend", "(E2) ECI + Dummy")
}

stargazer(
  model_list,
  type = "latex",
  title = "Time-Trend Regressions: Manufacturing VA and ECI, Uzbekistan 2010--2023",
  label = "tab:trend_regression",
  column.labels = col_labels,
  dep.var.labels = c("Manufacturing VA (\\% GDP)", "ECI"),
  covariate.labels = c(
    "Time Trend", "Post-2017", "Trend $\\times$ Post-2017", "Constant"
  ),
  keep.stat = c("n", "rsq", "adj.rsq", "f"),
  notes = "OLS estimates. Time trend = year $-$ 2010. Post-2017 = 1 if year $\\geq$ 2017.",
  notes.append = FALSE,
  notes.align = "l",
  out = "output/tables/table_trend_regression.tex"
)

# Log
sink("output/logs/trend_regression_log.txt")
cat("TREND REGRESSION LOG\n")
cat("Date:", format(Sys.Date()), "\n\n")

cat("=== Manufacturing VA Models ===\n")
cat("T1: Trend only\n");     print(summary(t1))
cat("\nT2: Trend + Dummy\n"); print(summary(t2))
cat("\nT3: Full interaction\n"); print(summary(t3))

cat("\n=== HC3 Robust SEs ===\n")
cat("T1 HC3:\n"); print(t1_hc)
cat("T2 HC3:\n"); print(t2_hc)
cat("T3 HC3:\n"); print(t3_hc)

cat("\n=== Pre/Post Slope Comparison ===\n")
cat("Pre-2017 slope: ", round(coef(pre_trend)["time_trend"], 4), "\n")
cat("Post-2017 slope:", round(coef(post_trend)["time_trend"], 4), "\n")

if (length(eci_models) > 0) {
  cat("\n=== ECI Models ===\n")
  for (nm in names(eci_models)) {
    cat(nm, ":\n"); print(summary(eci_models[[nm]]))
  }
}
sink()

cat("Trend regression analysis complete.\n")
cat("  output/tables/table_trend_regression.tex\n")
cat("  output/logs/trend_regression_log.txt\n")
