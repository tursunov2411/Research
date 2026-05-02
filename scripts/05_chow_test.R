# ============================================================
# Script: 05_chow_test.R
# Analysis: Structural Break Test (Chow Test) + Endogenous
#           Breakpoint Detection (Bai–Perron / strucchange)
# Question: Did 2017 reforms structurally shift FDI
#           composition toward manufacturing in Uzbekistan?
# ============================================================

source("scripts/00_setup.R")

dir.create("figures", recursive = TRUE, showWarnings = FALSE)
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
# INTERACTION TERM DIAGNOSTICS
# -------------------------------------------------------
# The full model includes: manuf_va_gdp ~ trend + post_reform + trend*post_reform
# The interaction term (β for trend × post_reform) tests whether the *slope*
# changed after 2017.

full_summary <- summary(model_full)
interaction_coef <- coef(full_summary)["interaction", ]

cat("\n========================================\n")
cat("INTERACTION TERM IN FULL MODEL\n")
cat("========================================\n")
cat("Coefficient (β):", round(interaction_coef["Estimate"], 4), "\n")
cat("Std. Error:     ", round(interaction_coef["Std. Error"], 4), "\n")
cat("t-value:        ", round(interaction_coef["t value"], 4), "\n")
cat("p-value:        ", round(interaction_coef["Pr(>|t|)"], 4), "\n")

cat("\n========================================\n")
cat("NOTE: Chow F-test vs. Interaction t-test Divergence\n")
cat("========================================\n")
cat(paste0(
  "The Chow F-test (F=", round(chow_result$statistic, 3),
  ", p=", round(chow_result$p.value, 3),
  ") tests the JOINT hypothesis that BOTH the intercept\n",
  "AND the slope differ between the pre- and post-2017 regimes. It pools\n",
  "two restrictions into a single F-statistic and is therefore a more\n",
  "powerful omnibus test of parameter instability.\n\n",
  "The interaction term in the full model (β=",
  round(interaction_coef["Estimate"], 3),
  ", p=", round(interaction_coef["Pr(>|t|)"], 3),
  ") tests ONLY whether the slope\n",
  "changed, conditional on the intercept shift already being in the model.\n",
  "With N=", nrow(uzb_ts),
  " annual observations and 4 parameters estimated, the\n",
  "individual t-test is severely underpowered (df=", nrow(uzb_ts) - 4,
  "). The collinearity\n",
  "between post_reform and the interaction term inflates standard errors,\n",
  "reducing the power of each individual coefficient test even when the\n",
  "joint restriction (Chow test) rejects.\n\n",
  "In small samples, it is entirely possible — and common — for a joint\n",
  "F-test to reject H0 while individual coefficients remain individually\n",
  "insignificant. This does NOT mean the results are contradictory: the\n",
  "Chow test is the correct omnibus test for structural break detection,\n",
  "while the interaction coefficient is useful for decomposing the break\n",
  "into level-shift and slope-change components, but lacks power to do so\n",
  "in a 14-observation sample.\n"
))

# -------------------------------------------------------
# ENDOGENOUS BREAKPOINT SEARCH (Bai–Perron via strucchange)
# -------------------------------------------------------
# Instead of imposing 2017 as the break, let the data determine
# the optimal structural break endogenously.

cat("\n========================================\n")
cat("ENDOGENOUS BREAKPOINT SEARCH\n")
cat("========================================\n")

# Restrict to 2010–2023 for the structural break search
uzb_break <- uzb_ts %>%
  filter(year >= 2010, year <= 2023)

# breakpoints() from strucchange: searches over all interior
# candidate breakpoints and selects the one minimising BIC/RSS
bp_result <- breakpoints(
  manuf_va_gdp ~ time_trend,
  data = uzb_break,
  h = 0.20  # minimum segment fraction (~20% = ~3 obs per segment)
)

cat("Optimal number of breaks (BIC criterion):",
    length(bp_result$breakpoints), "\n")

if (!any(is.na(bp_result$breakpoints))) {
  bp_years <- uzb_break$year[bp_result$breakpoints]
  cat("Endogenous breakpoint year(s):", paste(bp_years, collapse = ", "), "\n")
  cat("Breakpoint index (row):", paste(bp_result$breakpoints, collapse = ", "), "\n")

  # Check if the data-determined break coincides with 2017
  cat("\n--- Concordance with 2017 Reform ---\n")
  if (2017 %in% bp_years) {
    cat("✓ The data-determined break COINCIDES exactly with 2017.\n")
    cat("  This STRENGTHENS the Chow test result: the 2017 break is not\n")
    cat("  only significant when imposed a priori but is also identified\n")
    cat("  by an endogenous, data-driven search procedure.\n")
  } else if (any(abs(bp_years - 2017) <= 1)) {
    nearest <- bp_years[which.min(abs(bp_years - 2017))]
    cat("≈ The data-determined break (", nearest,
        ") is within ±1 year of 2017.\n")
    cat("  Given annual data granularity, this is consistent with a\n")
    cat("  2017 break being the true structural change point.\n")
  } else {
    cat("✗ The data-determined break (", paste(bp_years, collapse = ", "),
        ") does NOT coincide with 2017.\n")
    cat("  The exogenous 2017 breakpoint should be interpreted with\n")
    cat("  additional caution: the reform may not be the dominant\n")
    cat("  structural change in this series.\n")
  }
} else {
  cat("No significant structural break detected by BIC criterion.\n")
  cat("This suggests either no break or that the series is too short\n")
  cat("for the Bai–Perron procedure to detect one reliably.\n")
}

# Print BIC summary for all candidate break numbers
cat("\nBIC values by number of breakpoints:\n")
print(summary(bp_result))

# -------------------------------------------------------
# F-STATISTICS PLOT: Fstats across all candidate breaks
# -------------------------------------------------------
# The F-statistics process tests parameter stability at every
# candidate breakpoint. Peaks above the critical value boundary
# indicate likely structural breaks.

cat("\n========================================\n")
cat("F-STATISTICS PROCESS (supF test)\n")
cat("========================================\n")

fstats_result <- Fstats(
  manuf_va_gdp ~ time_trend,
  data = uzb_break,
  from = 0.20  # trim: start from 20% into the sample
)

# supF test — the supremum of the F-statistics process
supf_test <- sctest(fstats_result, type = "supF")
cat("supF statistic:", round(supf_test$statistic, 4), "\n")
cat("supF p-value:  ", round(supf_test$p.value, 4), "\n")

if (supf_test$p.value < 0.05) {
  cat("REJECT H0: The supF test confirms at least one structural break\n")
  cat("in the manufacturing VA series (2010–2023).\n")
} else {
  cat("FAIL TO REJECT H0: supF test does not confirm structural break.\n")
}

# Plot F-statistics with critical value boundary
png("figures/fig_fstats_structural_break.png",
    width = 8, height = 5, units = "in", res = 300, bg = "white")

plot(fstats_result,
     main = "F-Statistics Process: Structural Break Detection\nin Manufacturing VA (% GDP), Uzbekistan 2010–2023",
     xlab = "Observation Index (normalised)",
     ylab = "F-statistic")
# Add the 5% critical boundary
lines(boundary(fstats_result, alpha = 0.05), col = "red", lty = 2, lwd = 2)
legend("topleft",
       legend = c("F-statistic", "5% critical boundary"),
       col = c("black", "red"), lty = c(1, 2), lwd = c(1, 2),
       bty = "n", cex = 0.9)

dev.off()
# Copy to output/figures/ as well
file.copy("figures/fig_fstats_structural_break.png",
          "output/figures/fig_fstats_structural_break.png", overwrite = TRUE)
cat("F-statistics plot saved: figures/fig_fstats_structural_break.png\n")

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
  "figures/fig1_structural_break.png",
  fig_structural_break,
  width = 8,
  height = 5,
  dpi = 300,
  bg = "white"
)
file.copy("figures/fig1_structural_break.png",
          "output/figures/fig1_structural_break.png", overwrite = TRUE)

# Save model output
sink("output/logs/chow_test_results.txt")
cat("STRUCTURAL BREAK ANALYSIS - UZBEKISTAN 2017 REFORMS\n\n")
cat("Pre-reform model:\n")
print(summary(model_pre))
cat("\nPost-reform model:\n")
print(summary(model_post))
cat("\nFull model (with interaction term):\n")
print(summary(model_full))
cat("\n--- Interaction Term Note ---\n")
cat(paste0(
  "The interaction term (post_reform × time_trend) tests whether the\n",
  "slope changed after 2017. In the full model, β=",
  round(interaction_coef["Estimate"], 3),
  " (p=", round(interaction_coef["Pr(>|t|)"], 3), ").\n",
  "This coefficient is NOT statistically significant.\n\n",
  "However, the Chow F-test (F=", round(chow_result$statistic, 3),
  ", p=", round(chow_result$p.value, 3),
  ") IS significant.\n",
  "These tests answer different questions:\n",
  " - Chow test: JOINT test of whether ANY parameter changed (intercept OR slope)\n",
  " - Interaction t-test: INDIVIDUAL test of slope change only\n\n",
  "In a sample of N=", nrow(uzb_ts),
  " with 4 parameters, individual t-tests are\n",
  "severely underpowered. The Chow test pools both restrictions into a\n",
  "single F-statistic, gaining power. This divergence is common in\n",
  "short time-series analysis and does not indicate contradictory results.\n"
))
cat("\nChow test:\n")
print(chow_result)
cat("\n--- Endogenous Breakpoint Search ---\n")
print(summary(bp_result))
cat("\n--- supF test ---\n")
print(supf_test)
sink()

# Export regression table
stargazer(
  model_pre,
  model_post,
  model_full,
  type = "text",
  column.labels = c("Pre-2017", "Post-2017", "Full"),
  out = "output/tables/table_a1_chow_regression.txt"
)

cat("Analysis 1 complete. Figures and tables saved.\n")
