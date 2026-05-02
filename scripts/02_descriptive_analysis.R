# ============================================================
# Script: 02_descriptive_analysis.R
# Purpose: Generate descriptive statistics for all variables
#          used in the dissertation (Table 1 equivalents).
# Outputs: output/tables/table_descriptive_stats.csv
#          output/tables/table_descriptive_stats.tex
#          output/logs/descriptive_stats_log.txt
# ============================================================

source("scripts/00_setup.R")

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs",   recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------
# 1. LOAD PROCESSED DATA
# -------------------------------------------------------

wb <- readRDS("data/processed/wb_indicators.rds")

# Focus on Uzbekistan, the primary case, 2010–2023
uzb <- wb %>%
  filter(country_code == "UZB", year >= 2010, year <= 2023) %>%
  select(year, manuf_va_gdp, fdi_gdp, gdp_per_capita,
         lpi_score, tertiary_enrolment, unemployment) %>%
  arrange(year)

# Load ECI if available
eci <- tryCatch(
  readRDS("data/processed/eci_data.rds") %>%
    filter(country_code == "UZB") %>%
    select(year, eci),
  error = function(e) {
    message("ECI data not found; skipping ECI column.")
    NULL
  }
)

if (!is.null(eci)) {
  uzb <- uzb %>% left_join(eci, by = "year")
}

# Load intermediate goods share if available
interm <- tryCatch(
  read_csv("output/tables/table_intermediate_goods_share.csv",
           show_col_types = FALSE) %>%
    group_by(year) %>%
    summarise(
      interm_share = sum(intermediate_imports_usd, na.rm = TRUE) /
                     sum(total_imports_usd, na.rm = TRUE),
      .groups = "drop"
    ),
  error = function(e) {
    message("Intermediate goods data not found; skipping interm_share column.")
    NULL
  }
)

if (!is.null(interm)) {
  uzb <- uzb %>% left_join(interm, by = "year")
}

# -------------------------------------------------------
# 2. COMPUTE DESCRIPTIVE STATISTICS
# -------------------------------------------------------

# Variables to summarise (dynamically include what's available)
vars_to_summarise <- c(
  "manuf_va_gdp", "fdi_gdp", "gdp_per_capita",
  "lpi_score", "tertiary_enrolment", "unemployment"
)
if ("eci" %in% names(uzb)) vars_to_summarise <- c(vars_to_summarise, "eci")
if ("interm_share" %in% names(uzb)) vars_to_summarise <- c(vars_to_summarise, "interm_share")

# Readable labels
var_labels <- c(
  manuf_va_gdp      = "Manufacturing VA (% GDP)",
  fdi_gdp           = "FDI Inflows (% GDP)",
  gdp_per_capita    = "GDP per Capita (current USD)",
  lpi_score         = "Logistics Performance Index",
  tertiary_enrolment= "Tertiary Enrolment Rate (%)",
  unemployment      = "Unemployment (%)",
  eci               = "Economic Complexity Index",
  interm_share      = "Intermediate Goods Share (NE Asia)"
)

desc_stats <- uzb %>%
  select(all_of(vars_to_summarise)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  filter(!is.na(value)) %>%
  group_by(variable) %>%
  summarise(
    N    = n(),
    Mean = mean(value),
    SD   = sd(value),
    Min  = min(value),
    Max  = max(value),
    Median = median(value),
    .groups = "drop"
  ) %>%
  mutate(
    Label = var_labels[variable],
    across(where(is.numeric) & !c("N"), ~ round(.x, 3))
  ) %>%
  select(Label, variable, N, Mean, SD, Min, Median, Max) %>%
  arrange(variable)

# -------------------------------------------------------
# 3. TRENDS: Pre vs Post 2017
# -------------------------------------------------------

uzb_period <- uzb %>%
  mutate(period = ifelse(year < 2017, "Pre-2017", "Post-2017"))

trend_comparison <- uzb_period %>%
  select(period, all_of(vars_to_summarise)) %>%
  pivot_longer(-period, names_to = "variable", values_to = "value") %>%
  filter(!is.na(value)) %>%
  group_by(period, variable) %>%
  summarise(
    N    = n(),
    Mean = round(mean(value), 3),
    SD   = round(sd(value), 3),
    .groups = "drop"
  ) %>%
  mutate(Label = var_labels[variable]) %>%
  select(Label, variable, period, N, Mean, SD) %>%
  arrange(variable, period)

# -------------------------------------------------------
# 4. ANNUAL GROWTH RATES (for key variables)
# -------------------------------------------------------

annual_growth <- uzb %>%
  arrange(year) %>%
  mutate(
    manuf_va_change  = manuf_va_gdp - lag(manuf_va_gdp),
    fdi_change       = fdi_gdp - lag(fdi_gdp),
    gdp_pc_growth    = (gdp_per_capita / lag(gdp_per_capita) - 1) * 100
  ) %>%
  filter(!is.na(manuf_va_change)) %>%
  select(year, manuf_va_change, fdi_change, gdp_pc_growth)

# -------------------------------------------------------
# 5. MULTI-COUNTRY COMPARISON (for context)
# -------------------------------------------------------

comparators <- wb %>%
  filter(country_code %in% c("UZB", "VNM", "KAZ", "CHN", "KOR"),
         year >= 2010, year <= 2023) %>%
  group_by(country_code) %>%
  summarise(
    mean_manuf_va = round(mean(manuf_va_gdp, na.rm = TRUE), 2),
    mean_fdi      = round(mean(fdi_gdp, na.rm = TRUE), 2),
    mean_gdp_pc   = round(mean(gdp_per_capita, na.rm = TRUE), 0),
    .groups = "drop"
  )

# -------------------------------------------------------
# 6. EXPORT RESULTS
# -------------------------------------------------------

# CSV
write_csv(desc_stats, "output/tables/table_descriptive_stats.csv")
write_csv(trend_comparison, "output/tables/table_descriptive_stats_by_period.csv")
write_csv(annual_growth, "output/tables/table_annual_growth.csv")
write_csv(comparators, "output/tables/table_comparator_means.csv")

# LaTeX table
stargazer(
  uzb %>% select(all_of(vars_to_summarise)) %>% as.data.frame(),
  type = "latex",
  title = "Descriptive Statistics: Uzbekistan Key Indicators, 2010--2023",
  label = "tab:descriptive",
  summary = TRUE,
  out = "output/tables/table_descriptive_stats.tex"
)

# Log
sink("output/logs/descriptive_stats_log.txt")
cat("DESCRIPTIVE STATISTICS LOG\n")
cat("Date:", format(Sys.Date()), "\n")
cat("Country: Uzbekistan | Period: 2010–2023\n\n")

cat("=== Full-Sample Summary ===\n")
print(desc_stats)

cat("\n=== Pre vs Post 2017 Comparison ===\n")
print(trend_comparison %>% pivot_wider(names_from = period, values_from = c(N, Mean, SD)))

cat("\n=== Annual Growth Rates ===\n")
print(annual_growth)

cat("\n=== Multi-Country Comparator Means ===\n")
print(comparators)
sink()

cat("Descriptive analysis complete.\n")
cat("  output/tables/table_descriptive_stats.csv\n")
cat("  output/tables/table_descriptive_stats_by_period.csv\n")
cat("  output/tables/table_annual_growth.csv\n")
cat("  output/tables/table_comparator_means.csv\n")
cat("  output/tables/table_descriptive_stats.tex\n")
