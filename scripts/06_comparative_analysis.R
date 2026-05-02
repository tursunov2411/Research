# ============================================================
# Script: 06_comparative_analysis.R
# Analysis: Uzbekistan vs Vietnam - GVC Readiness Comparison
# Comparable reform stages: VNM 2000-2008, UZB 2017-2023
# ============================================================

source("scripts/00_setup.R")

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

wb_data <- readRDS("data/processed/wb_indicators.rds")
eci_data <- readRDS("data/processed/eci_data.rds")

# -------------------------------------------------------
# COMPARABLE REFORM STAGE ALIGNMENT
# Vietnam reform baseline: 2000 (t=0)
# Uzbekistan reform baseline: 2017 (t=0)
# Compare t+0 through t+8 where data are available
# -------------------------------------------------------

# Backfill Vietnam 2000-2008 if the processed World Bank file
# only contains the main 2010-2023 thesis period.
if (!any(wb_data$country_code == "VNM" & wb_data$year %in% 2000:2008)) {
  vnm_early <- WDI(
    country = "VNM",
    indicator = c(
      "NV.IND.MANF.ZS",
      "BX.KLT.DINV.WD.GD.ZS",
      "LP.LPI.OVRL.XQ"
    ),
    start = 2000,
    end = 2008,
    extra = TRUE
  ) %>%
    rename(
      country_code = iso3c,
      manuf_va_gdp = NV.IND.MANF.ZS,
      fdi_gdp = BX.KLT.DINV.WD.GD.ZS,
      lpi_score = LP.LPI.OVRL.XQ
    ) %>%
    mutate(
      doing_business_rank = NA_real_,
      doing_business_score = NA_real_
    )

  wb_data <- bind_rows(wb_data, vnm_early)
}

vnm_reform <- wb_data %>%
  filter(
    country_code == "VNM",
    year %in% 2000:2008
  ) %>%
  mutate(
    reform_year = year - 2000,
    country_label = "Vietnam (post-2000)"
  )

uzb_reform <- wb_data %>%
  filter(
    country_code == "UZB",
    year %in% 2017:2023
  ) %>%
  mutate(
    reform_year = year - 2017,
    country_label = "Uzbekistan (post-2017)"
  )

comparison_data <- bind_rows(vnm_reform, uzb_reform) %>%
  select(
    country_label,
    country_code,
    year,
    reform_year,
    manuf_va_gdp,
    fdi_gdp,
    lpi_score,
    doing_business_score
  )

eci_reform <- eci_data %>%
  mutate(
    reform_year = case_when(
      country_code == "VNM" ~ year - 2000,
      country_code == "UZB" ~ year - 2017,
      TRUE ~ NA_integer_
    ),
    country_label = case_when(
      country_code == "VNM" ~ "Vietnam (post-2000)",
      country_code == "UZB" ~ "Uzbekistan (post-2017)",
      TRUE ~ country_code
    )
  ) %>%
  filter(
    country_code %in% c("UZB", "VNM"),
    reform_year >= 0,
    reform_year <= 8
  )

# -------------------------------------------------------
# COMPARATIVE MULTI-PANEL FIGURE
# -------------------------------------------------------

comparison_colours <- c(
  "Vietnam (post-2000)" = unname(thesis_colours["neutral"]),
  "Uzbekistan (post-2017)" = unname(thesis_colours["uzbekistan"])
)

p_manuf <- ggplot(
  comparison_data,
  aes(
    x = reform_year,
    y = manuf_va_gdp,
    color = country_label,
    group = country_label
  )
) +
  geom_line(linewidth = 1.3, na.rm = TRUE) +
  geom_point(size = 3, na.rm = TRUE) +
  scale_color_manual(values = comparison_colours) +
  labs(
    title = "A. Manufacturing Value Added (% GDP)",
    x = "Years Since Reform",
    y = "% of GDP",
    color = NULL
  )

p_fdi <- ggplot(
  comparison_data,
  aes(
    x = reform_year,
    y = fdi_gdp,
    color = country_label,
    group = country_label
  )
) +
  geom_line(linewidth = 1.3, na.rm = TRUE) +
  geom_point(size = 3, na.rm = TRUE) +
  scale_color_manual(values = comparison_colours) +
  labs(
    title = "B. FDI Inflows (% of GDP)",
    x = "Years Since Reform",
    y = "% of GDP",
    color = NULL
  )

p_lpi <- ggplot(
  comparison_data,
  aes(
    x = reform_year,
    y = lpi_score,
    color = country_label,
    group = country_label
  )
) +
  geom_line(linewidth = 1.3, na.rm = TRUE) +
  geom_point(size = 3, na.rm = TRUE) +
  scale_color_manual(values = comparison_colours) +
  labs(
    title = "C. Logistics Performance Index",
    x = "Years Since Reform",
    y = "LPI Score (1-5)",
    color = NULL
  )

fig_comparison <- p_manuf + p_fdi + p_lpi +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Figure 4. Uzbekistan vs Vietnam: Comparative Reform Trajectory",
    subtitle = "Indicators aligned to comparable reform stages (Vietnam t=2000, Uzbekistan t=2017)",
    caption = paste0(
      "Source: World Bank World Development Indicators.\n",
      "Note: Vietnam years represent 2000-2008; Uzbekistan years represent 2017-2023."
    ),
    theme = theme(plot.title = element_text(face = "bold", size = 14))
  )

ggsave(
  "output/figures/fig4_comparative_trajectory.png",
  fig_comparison,
  width = 14,
  height = 5,
  dpi = 300,
  bg = "white"
)

# -------------------------------------------------------
# SUMMARY SCORECARD TABLE
# -------------------------------------------------------

scorecard <- comparison_data %>%
  group_by(country_label) %>%
  summarise(
    `Avg Manufacturing VA (% GDP)` = round(mean(manuf_va_gdp, na.rm = TRUE), 2),
    `Avg FDI (% GDP)` = round(mean(fdi_gdp, na.rm = TRUE), 2),
    `Avg LPI Score` = round(mean(lpi_score, na.rm = TRUE), 2),
    `Avg Doing Business Score` = round(mean(doing_business_score, na.rm = TRUE), 2),
    `Peak FDI (% GDP)` = round(max(fdi_gdp, na.rm = TRUE), 2),
    .groups = "drop"
  )

eci_scorecard <- eci_reform %>%
  group_by(country_label) %>%
  summarise(
    `Avg ECI` = round(mean(eci, na.rm = TRUE), 3),
    .groups = "drop"
  )

scorecard <- scorecard %>%
  left_join(eci_scorecard, by = "country_label")

write_csv(scorecard, "output/tables/table_comparison_scorecard.csv")
write_csv(comparison_data, "data/processed/comparative_reform_trajectory.csv")
print(scorecard)

# -------------------------------------------------------
# ROBUSTNESS CHECK: PANEL REGRESSION (N=14 problem resolution)
# Model: MfgVA_it = α_i + β1 FDI_it + β2 TradeOpen_it + β3 Post2017_it + ε_it
# -------------------------------------------------------

# Fetch trade openness and comparator data if missing
panel_countries <- c("UZB", "VNM", "KAZ", "GEO", "RWA")
panel_wdi <- WDI(
  country = panel_countries,
  indicator = c(
    "NV.IND.MANF.ZS",       # manuf_va_gdp
    "BX.KLT.DINV.WD.GD.ZS", # fdi_gdp
    "NE.TRD.GNFS.ZS"        # trade_openness
  ),
  start = 2010,
  end = 2023,
  extra = TRUE
) %>%
  rename(
    country_code = iso3c,
    manuf_va_gdp = NV.IND.MANF.ZS,
    fdi_gdp = BX.KLT.DINV.WD.GD.ZS,
    trade_openness = NE.TRD.GNFS.ZS
  ) %>%
  mutate(post_2017 = ifelse(year >= 2017, 1, 0))

# Fixed effects regression (using LSDV approach with country dummies)
panel_model <- lm(manuf_va_gdp ~ fdi_gdp + trade_openness + post_2017 + factor(country_code), data = panel_wdi)

# Save the model summary to output
sink("output/tables/panel_robustness_summary.txt")
cat("Panel Regression: Robustness Check for N=14 Problem\n")
cat("Countries: UZB, VNM, KAZ, GEO, RWA\n")
cat("Period: 2010-2023\n")
cat("========================================================\n")
print(summary(panel_model))
sink()

cat("Panel robustness check complete. Results saved to output/tables/panel_robustness_summary.txt\n")

cat("Comparative analysis complete.\n")
