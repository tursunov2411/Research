# ============================================================
# Script: 05_chow_test.R
# Analysis: Structural Break Test (Chow Test)
# Question: Did 2017 reforms structurally shift FDI
#           composition toward manufacturing in Uzbekistan?
# ============================================================

source("scripts/00_setup.R")

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

wb_data <- readRDS("data/processed/wb_indicators.rds")

# Prepare Uzbekistan time series
uzb_ts <- wb_data %>%
  filter(country_code == "UZB") %>%
  arrange(year) %>%
  select(year, manuf_va_gdp, fdi_gdp) %>%
  filter(!is.na(manuf_va_gdp))

# -------------------------------------------------------
# CHOW TEST: Structural break at 2017
# -------------------------------------------------------
# H0: No structural break at 2017
# H1: Structural break exists at 2017

uzb_ts <- uzb_ts %>%
  mutate(
    post_reform = ifelse(year >= 2017, 1, 0),
    time_trend = year - min(year),
    interaction = post_reform * time_trend
  )

if (!2017 %in% uzb_ts$year) {
  stop("Cannot run Chow test: year 2017 is not present in Uzbekistan data.")
}

# Full model
model_full <- lm(
  manuf_va_gdp ~ time_trend + post_reform + interaction,
  data = uzb_ts
)

# Pre-reform model
model_pre <- lm(
  manuf_va_gdp ~ time_trend,
  data = filter(uzb_ts, year < 2017)
)

# Post-reform model
model_post <- lm(
  manuf_va_gdp ~ time_trend,
  data = filter(uzb_ts, year >= 2017)
)

# Chow test using strucchange package
breakpoint_index <- which(uzb_ts$year == 2017)
chow_result <- sctest(
  manuf_va_gdp ~ time_trend,
  type = "Chow",
  point = breakpoint_index,
  data = uzb_ts
)

cat("\n========================================\n")
cat("CHOW TEST RESULTS\n")
cat("========================================\n")
cat("Test: Structural break at 2017\n")
cat("F-statistic:", round(chow_result$statistic, 4), "\n")
cat("p-value:", round(chow_result$p.value, 4), "\n")
cat("Interpretation: ")
if (chow_result$p.value < 0.05) {
  cat("REJECT H0 - Significant structural break detected at 2017\n")
  cat("This supports the argument that reforms shifted the manufacturing trajectory.\n")
} else {
  cat("FAIL TO REJECT H0 - No significant structural break\n")
  cat("Interpret honestly: reforms may need more time or may affect other channels.\n")
}

# -------------------------------------------------------
# VISUALISATION: Before/After Reform Trend
# -------------------------------------------------------

fig_structural_break <- ggplot(uzb_ts, aes(x = year, y = manuf_va_gdp)) +
  geom_vline(
    xintercept = 2017,
    linetype = "dashed",
    color = thesis_colours["highlight"],
    linewidth = 1
  ) +
  geom_point(size = 3, color = thesis_colours["uzbekistan"]) +
  geom_smooth(
    data = filter(uzb_ts, year < 2017),
    method = "lm",
    se = TRUE,
    color = thesis_colours["neutral"],
    fill = "grey80"
  ) +
  geom_smooth(
    data = filter(uzb_ts, year >= 2017),
    method = "lm",
    se = TRUE,
    color = thesis_colours["uzbekistan"],
    fill = "#AED6F1"
  ) +
  annotate(
    "text",
    x = 2017.2,
    y = max(uzb_ts$manuf_va_gdp, na.rm = TRUE),
    label = "Reform\nBreakpoint",
    hjust = 0,
    size = 3.5,
    color = thesis_colours["highlight"]
  ) +
  labs(
    title = "Figure 1. Manufacturing Value Added in Uzbekistan",
    subtitle = "Structural break test at 2017 reform breakpoint",
    x = "Year",
    y = "Manufacturing VA (% of GDP)",
    caption = paste0(
      "Source: World Bank World Development Indicators.\n",
      "Shaded areas represent 95% confidence intervals.\n",
      "Dashed line indicates 2017 reform breakpoint.\n",
      "Chow test F-stat: ", round(chow_result$statistic, 3),
      ", p = ", round(chow_result$p.value, 3)
    )
  )

ggsave(
  "output/figures/fig1_structural_break.png",
  fig_structural_break,
  width = 8,
  height = 5,
  dpi = 300,
  bg = "white"
)

# Save model output
sink("output/logs/chow_test_results.txt")
cat("STRUCTURAL BREAK ANALYSIS - UZBEKISTAN 2017 REFORMS\n\n")
cat("Pre-reform model:\n")
print(summary(model_pre))
cat("\nPost-reform model:\n")
print(summary(model_post))
cat("\nFull model:\n")
print(summary(model_full))
cat("\nChow test:\n")
print(chow_result)
sink()

# Export regression table
stargazer(
  model_pre,
  model_post,
  model_full,
  type = "text",
  title = "Table A1: Structural Break Regression Results",
  column.labels = c("Pre-2017", "Post-2017", "Full"),
  out = "output/tables/table_a1_chow_regression.txt"
)

cat("Analysis 1 complete. Figures and tables saved.\n")
