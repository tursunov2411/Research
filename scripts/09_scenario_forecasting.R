# ============================================================
# Script: 09_scenario_forecasting.R
# Analysis: Manufacturing and Export Complexity Forecasting
# Purpose: Project Uzbekistan's manufacturing value added,
#          FDI intensity, and economic complexity through 2030
#          under three policy scenarios.
# ============================================================

source("scripts/00_setup.R")

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

FORECAST_END <- 2030
REFORM_YEAR <- 2017

safe_tail <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  tail(x, 1)
}

safe_mean <- function(x) {
  if (length(x) == 0 || all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

safe_fit_forecast <- function(values, years, h) {
  observed <- tibble(year = years, value = values) %>%
    filter(!is.na(value)) %>%
    arrange(year)

  if (nrow(observed) < 4) {
    stop("Not enough observations to estimate a forecast.")
  }

  series <- ts(observed$value, start = min(observed$year), frequency = 1)

  arima_fit <- tryCatch(
    forecast::auto.arima(
      series,
      seasonal = FALSE,
      stepwise = FALSE,
      approximation = FALSE
    ),
    error = function(e) NULL
  )

  if (!is.null(arima_fit)) {
    fc <- forecast::forecast(arima_fit, h = h, level = 80)

    return(list(
      model = paste(forecast::arimaorder(arima_fit), collapse = ","),
      mean = as.numeric(fc$mean),
      lower = as.numeric(fc$lower[, 1]),
      upper = as.numeric(fc$upper[, 1]),
      method = "ARIMA"
    ))
  }

  linear_fit <- lm(value ~ year, data = observed)
  future_years <- seq(max(observed$year) + 1, by = 1, length.out = h)
  predicted <- as.numeric(predict(linear_fit, newdata = data.frame(year = future_years)))
  residual_sd <- sd(residuals(linear_fit), na.rm = TRUE)

  list(
    model = "linear-trend fallback",
    mean = predicted,
    lower = predicted - 1.2816 * residual_sd,
    upper = predicted + 1.2816 * residual_sd,
    method = "Linear Trend"
  )
}

annual_change_mean <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 2) {
    return(NA_real_)
  }
  safe_mean(diff(x))
}

message("\n========================================")
message("ANALYSIS 9: SCENARIO FORECASTING")
message("========================================")

wb_data <- readRDS("data/processed/wb_indicators.rds")
eci_data <- readRDS("data/processed/eci_data.rds")

uzb_wb <- wb_data %>%
  filter(country_code == "UZB") %>%
  arrange(year)

uzb_eci <- eci_data %>%
  filter(country_code == "UZB") %>%
  arrange(year)

vnm_wb <- wb_data %>%
  filter(country_code == "VNM", year %in% 2010:2016) %>%
  arrange(year)

vnm_eci <- eci_data %>%
  filter(country_code == "VNM", year %in% 2010:2016) %>%
  arrange(year)

vnm_benchmark <- tibble(
  metric = c("Manufacturing VA (% GDP)", "FDI inflows (% GDP)", "ECI"),
  vietnam_2010 = c(
    vnm_wb %>% filter(year == 2010) %>% pull(manuf_va_gdp) %>% first(),
    vnm_wb %>% filter(year == 2010) %>% pull(fdi_gdp) %>% first(),
    vnm_eci %>% filter(year == 2010) %>% pull(eci) %>% first()
  ),
  vietnam_avg_annual_change = c(
    annual_change_mean(vnm_wb$manuf_va_gdp),
    annual_change_mean(vnm_wb$fdi_gdp),
    annual_change_mean(vnm_eci$eci)
  )
)

message("\nVietnam benchmark average annual changes, 2010-2016:")
walk(seq_len(nrow(vnm_benchmark)), function(i) {
  message(
    "  ",
    vnm_benchmark$metric[i],
    ": ",
    round(vnm_benchmark$vietnam_avg_annual_change[i], 4)
  )
})

n_ahead <- FORECAST_END - max(uzb_wb$year, na.rm = TRUE)
forecast_years <- seq(max(uzb_wb$year, na.rm = TRUE) + 1, FORECAST_END)

manuf_fc <- safe_fit_forecast(uzb_wb$manuf_va_gdp, uzb_wb$year, n_ahead)
fdi_fc <- safe_fit_forecast(uzb_wb$fdi_gdp, uzb_wb$year, n_ahead)
eci_fc <- safe_fit_forecast(uzb_eci$eci, uzb_eci$year, n_ahead)

message("\nForecast model selection:")
message("  Manufacturing VA: ", manuf_fc$method, " [", manuf_fc$model, "]")
message("  FDI inflows: ", fdi_fc$method, " [", fdi_fc$model, "]")
message("  ECI: ", eci_fc$method, " [", eci_fc$model, "]")

scenario_palette <- c(
  "Historical" = "black",
  "A: Status Quo" = thesis_colours["neutral"],
  "B: Accelerated GVC Embedding" = thesis_colours["uzbekistan"],
  "C: Vietnam Trajectory" = thesis_colours["highlight"]
)

scenario_types <- c(
  "Historical" = "solid",
  "A: Status Quo" = "dashed",
  "B: Accelerated GVC Embedding" = "solid",
  "C: Vietnam Trajectory" = "dotdash"
)

manuf_vnm_change <- vnm_benchmark$vietnam_avg_annual_change[
  vnm_benchmark$metric == "Manufacturing VA (% GDP)"
]
fdi_vnm_change <- vnm_benchmark$vietnam_avg_annual_change[
  vnm_benchmark$metric == "FDI inflows (% GDP)"
]
eci_vnm_change <- vnm_benchmark$vietnam_avg_annual_change[
  vnm_benchmark$metric == "ECI"
]

scenario_params <- list(
  A = list(
    name = "A: Status Quo",
    manuf_step = 0,
    fdi_step = 0,
    eci_step = 0
  ),
  B = list(
    name = "B: Accelerated GVC Embedding",
    manuf_step = 0.35,
    fdi_step = 0.12,
    eci_step = 0.025
  ),
  C = list(
    name = "C: Vietnam Trajectory",
    manuf_step = manuf_vnm_change,
    fdi_step = fdi_vnm_change,
    eci_step = eci_vnm_change
  )
)

scenario_forecasts <- purrr::imap_dfr(
  scenario_params,
  function(sc, scenario_id) {
    step_index <- seq_along(forecast_years)

    tibble(
      scenario_id = scenario_id,
      scenario = sc$name,
      year = forecast_years,
      manuf_va = pmax(0, manuf_fc$mean + step_index * sc$manuf_step),
      fdi_gdp = pmax(0, fdi_fc$mean + step_index * sc$fdi_step),
      eci = eci_fc$mean + step_index * sc$eci_step,
      lo80_manuf = pmax(0, manuf_fc$lower),
      hi80_manuf = manuf_fc$upper,
      lo80_eci = eci_fc$lower,
      hi80_eci = eci_fc$upper,
      period = "forecast"
    )
  }
)

historical_series <- uzb_wb %>%
  select(year, manuf_va = manuf_va_gdp, fdi_gdp) %>%
  left_join(
    uzb_eci %>% select(year, eci),
    by = "year"
  ) %>%
  mutate(
    scenario_id = "H",
    scenario = "Historical",
    lo80_manuf = NA_real_,
    hi80_manuf = NA_real_,
    lo80_eci = NA_real_,
    hi80_eci = NA_real_,
    period = "historical"
  ) %>%
  select(
    scenario_id,
    scenario,
    year,
    manuf_va,
    fdi_gdp,
    eci,
    lo80_manuf,
    hi80_manuf,
    lo80_eci,
    hi80_eci,
    period
  )

full_series <- bind_rows(historical_series, scenario_forecasts)

write_csv(scenario_forecasts, "output/tables/table_scenario_forecasts.csv")

target_summary <- bind_rows(
  scenario_forecasts %>%
    group_by(scenario) %>%
    filter(manuf_va >= vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "Manufacturing VA (% GDP)"]) %>%
    slice_min(year, n = 1, with_ties = FALSE) %>%
    transmute(
      scenario,
      target_metric = "Manufacturing VA (% GDP)",
      target_value = vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "Manufacturing VA (% GDP)"],
      target_year = year,
      projected_value = manuf_va
    ),
  scenario_forecasts %>%
    group_by(scenario) %>%
    filter(eci >= vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "ECI"]) %>%
    slice_min(year, n = 1, with_ties = FALSE) %>%
    transmute(
      scenario,
      target_metric = "ECI",
      target_value = vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "ECI"],
      target_year = year,
      projected_value = eci
    )
) %>%
  arrange(target_metric, scenario)

write_csv(target_summary, "output/tables/table_scenario_target_years.csv")

message("\nPolicy target check against Vietnam 2010 benchmarks:")
if (nrow(target_summary) == 0) {
  message("  No scenario reaches the benchmark within 2024-2030.")
} else {
  walk(seq_len(nrow(target_summary)), function(i) {
    message(
      "  ",
      target_summary$scenario[i],
      " reaches ",
      target_summary$target_metric[i],
      " benchmark in ",
      target_summary$target_year[i]
    )
  })
}

fig_manuf_forecast <- full_series %>%
  filter(!is.na(manuf_va)) %>%
  ggplot(aes(x = year, y = manuf_va, color = scenario, linetype = scenario)) +
  geom_ribbon(
    data = filter(scenario_forecasts, scenario_id == "A"),
    aes(x = year, ymin = lo80_manuf, ymax = hi80_manuf),
    fill = thesis_colours["neutral"],
    alpha = 0.15,
    color = NA,
    inherit.aes = FALSE
  ) +
  geom_vline(
    xintercept = REFORM_YEAR,
    linetype = "dotted",
    color = thesis_colours["highlight"],
    linewidth = 0.8
  ) +
  geom_vline(
    xintercept = max(uzb_wb$year, na.rm = TRUE) + 0.5,
    linetype = "dotted",
    color = "grey60",
    linewidth = 0.8
  ) +
  geom_hline(
    yintercept = vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "Manufacturing VA (% GDP)"],
    linetype = "dashed",
    color = thesis_colours["vietnam"],
    linewidth = 0.8
  ) +
  geom_line(linewidth = 1.2, na.rm = TRUE) +
  scale_color_manual(values = scenario_palette, name = NULL) +
  scale_linetype_manual(values = scenario_types, name = NULL) +
  scale_x_continuous(breaks = seq(2010, FORECAST_END, 2)) +
  labs(
    title = "Figure 5. Uzbekistan Manufacturing Value Added Forecast, 2010-2030",
    subtitle = "Three policy scenarios diverge from 2024; shaded band is the 80% baseline forecast interval.",
    x = "Year",
    y = "Manufacturing Value Added (% GDP)",
    caption = paste(
      "Source: World Bank World Development Indicators and author calculations.",
      "Scenario A = baseline forecast;",
      "Scenario B = accelerated GVC embedding;",
      "Scenario C = Vietnam-calibrated annual change."
    )
  ) +
  theme(legend.position = "bottom")

ggsave(
  "output/figures/fig5_manufacturing_forecast.png",
  fig_manuf_forecast,
  width = 11,
  height = 6,
  dpi = 300,
  bg = "white"
)

p_manuf <- full_series %>%
  filter(!is.na(manuf_va)) %>%
  ggplot(aes(x = year, y = manuf_va, color = scenario, linetype = scenario)) +
  geom_line(linewidth = 1.1, na.rm = TRUE) +
  geom_vline(xintercept = max(uzb_wb$year, na.rm = TRUE) + 0.5, linetype = "dotted", color = "grey70") +
  scale_color_manual(values = scenario_palette, name = NULL) +
  scale_linetype_manual(values = scenario_types, name = NULL) +
  labs(title = "A. Manufacturing VA (% GDP)", x = "Year", y = "% of GDP")

p_fdi <- full_series %>%
  filter(!is.na(fdi_gdp)) %>%
  ggplot(aes(x = year, y = fdi_gdp, color = scenario, linetype = scenario)) +
  geom_line(linewidth = 1.1, na.rm = TRUE) +
  geom_vline(xintercept = max(uzb_wb$year, na.rm = TRUE) + 0.5, linetype = "dotted", color = "grey70") +
  scale_color_manual(values = scenario_palette, name = NULL) +
  scale_linetype_manual(values = scenario_types, name = NULL) +
  labs(title = "B. FDI Inflows (% GDP)", x = "Year", y = "% of GDP")

p_eci <- full_series %>%
  filter(!is.na(eci)) %>%
  ggplot(aes(x = year, y = eci, color = scenario, linetype = scenario)) +
  geom_line(linewidth = 1.1, na.rm = TRUE) +
  geom_vline(xintercept = max(uzb_eci$year, na.rm = TRUE) + 0.5, linetype = "dotted", color = "grey70") +
  geom_hline(
    yintercept = vnm_benchmark$vietnam_2010[vnm_benchmark$metric == "ECI"],
    linetype = "dashed",
    color = thesis_colours["vietnam"],
    linewidth = 0.7
  ) +
  scale_color_manual(values = scenario_palette, name = NULL) +
  scale_linetype_manual(values = scenario_types, name = NULL) +
  labs(title = "C. Economic Complexity Index", x = "Year", y = "ECI")

fig_dashboard <- p_manuf + p_fdi + p_eci +
  patchwork::plot_layout(guides = "collect", ncol = 3) +
  patchwork::plot_annotation(
    title = "Figure 6. Uzbekistan Scenario Dashboard, 2010-2030",
    subtitle = "Historical series through 2023 with scenario forecasts through 2030.",
    caption = paste(
      "Source: World Bank World Development Indicators, OEC Economic Complexity data, and author calculations.",
      "Vertical dotted lines mark the start of the forecast window."
    ),
    theme = theme(plot.title = element_text(size = 13, face = "bold", hjust = 0.5))
  ) &
  theme(legend.position = "bottom")

ggsave(
  "output/figures/fig6_scenario_dashboard.png",
  fig_dashboard,
  width = 14,
  height = 5.5,
  dpi = 300,
  bg = "white"
)

sink("output/logs/scenario_forecasting_log.txt")
cat("SCENARIO FORECASTING LOG\n")
cat("Date:", format(Sys.time()), "\n\n")
cat("Forecast horizon:", min(forecast_years), "-", max(forecast_years), "\n")
cat("Manufacturing model:", manuf_fc$method, "-", manuf_fc$model, "\n")
cat("FDI model:", fdi_fc$method, "-", fdi_fc$model, "\n")
cat("ECI model:", eci_fc$method, "-", eci_fc$model, "\n")
cat("\nVietnam benchmark table:\n")
print(vnm_benchmark)
cat("\nScenario target years:\n")
print(target_summary)
sink()

message("\nScenario forecasting complete.")
message("  Figures saved: fig5_manufacturing_forecast.png, fig6_scenario_dashboard.png")
message("  Tables saved: table_scenario_forecasts.csv, table_scenario_target_years.csv")
