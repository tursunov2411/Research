# ============================================================
# Script: 01_data_cleaning.R
# Purpose: Import, validate, and clean all raw datasets
# All raw files preserved unmodified in data/raw/
# ============================================================

source("scripts/00_setup.R")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------
# 1. LOAD WORLD BANK DATA DIRECTLY VIA API
# -----------------------------------------------------------
# This ensures full reproducibility: data pulled directly from
# World Bank servers with date stamp.

wb_indicators <- c(
  "NV.IND.MANF.ZS",       # Manufacturing value added % of GDP
  "BX.KLT.DINV.WD.GD.ZS", # FDI inflows % of GDP
  "NY.GDP.MKTP.CD",       # GDP current USD
  "NY.GDP.PCAP.CD",       # GDP per capita
  "LP.LPI.OVRL.XQ",       # Logistics Performance Index
  "SE.TER.ENRR",          # Tertiary education enrolment
  "SL.UEM.TOTL.ZS"        # Unemployment rate
)

wb_countries <- c("UZB", "VNM", "KAZ", "CHN", "KOR")

wb_data <- WDI(
  country   = wb_countries,
  indicator = wb_indicators,
  start     = 2010,
  end       = 2023,
  extra     = TRUE
)

# Rename for clarity
wb_clean <- wb_data %>%
  rename(
    country_code        = iso3c,
    manuf_va_gdp        = NV.IND.MANF.ZS,
    fdi_gdp             = BX.KLT.DINV.WD.GD.ZS,
    gdp_current         = NY.GDP.MKTP.CD,
    gdp_per_capita      = NY.GDP.PCAP.CD,
    lpi_score           = LP.LPI.OVRL.XQ,
    tertiary_enrolment  = SE.TER.ENRR,
    unemployment        = SL.UEM.TOTL.ZS
  ) %>%
  filter(!is.na(year)) %>%
  arrange(country_code, year)

# Add archived Doing Business values from the raw World Bank
# archive extract because the live WDI endpoint no longer serves
# the standard code without source-specific archive parameters.
doing_business_raw <- read_csv(
  "data/raw/doing_business_worldbank.csv",
  show_col_types = FALSE
)

doing_business_clean <- doing_business_raw %>%
  filter(indicator_code %in% c("IC.BUS.EASE.XQ", "IC.BUS.EASE.DFRN.XQ.DB1719")) %>%
  mutate(
    year = as.integer(year),
    value = as.numeric(value),
    indicator_key = case_when(
      indicator_code == "IC.BUS.EASE.XQ" ~ "doing_business_rank",
      indicator_code == "IC.BUS.EASE.DFRN.XQ.DB1719" ~ "doing_business_score",
      TRUE ~ indicator_code
    )
  ) %>%
  select(country_code, year, indicator_key, value) %>%
  pivot_wider(names_from = indicator_key, values_from = value)

wb_clean <- wb_clean %>%
  left_join(doing_business_clean, by = c("country_code", "year"))

# Log download date for reproducibility
attr(wb_clean, "download_date") <- Sys.Date()
cat("World Bank data downloaded:", format(Sys.Date()), "\n")
cat("Countries:", paste(unique(wb_clean$country), collapse = ", "), "\n")
cat("Years:", min(wb_clean$year, na.rm = TRUE), "-", max(wb_clean$year, na.rm = TRUE), "\n")

# -----------------------------------------------------------
# 2. LOAD UZBEK NATIONAL STATISTICS (PRIMARY DATA)
# -----------------------------------------------------------
# Current project raw file is the official SIAT/stat.uz CSV
# extracted during Phase 2. If a sector-level Excel workbook is
# later downloaded manually, place it in data/raw/ and adapt this
# section to read that file.

fdi_uzbek_raw <- read_csv(
  "data/raw/fdi_uzbekstat.csv",
  show_col_types = FALSE
)

cat("\nUzbek FDI data structure:\n")
glimpse(fdi_uzbek_raw)

fdi_uzbek <- fdi_uzbek_raw %>%
  transmute(
    country_code = "UZB",
    region_code = country_or_region_code,
    region = country_or_region,
    year = as.integer(year),
    indicator = indicator,
    foreign_investment_share = as.numeric(value_percent),
    source = source,
    source_url = source_url,
    note = note
  ) %>%
  filter(!is.na(foreign_investment_share))

# -----------------------------------------------------------
# 3. LOAD COMTRADE / BACI EXPORT DATA
# -----------------------------------------------------------
# UN Comtrade direct API requires credentials in this environment.
# The raw file was fetched from the public OEC/BACI API as HS
# section exports in USD and documented in source_manifest.csv.

exports_raw <- read_csv(
  "data/raw/exports_comtrade.csv",
  show_col_types = FALSE
)

exports_clean <- exports_raw %>%
  filter(country_code %in% c("UZB", "VNM")) %>%
  select(
    country_code,
    country,
    year,
    hs_section_code,
    hs_section,
    value_usd = trade_value_usd,
    source,
    source_url
  ) %>%
  mutate(
    year = as.integer(year),
    value_usd = as.numeric(value_usd)
  ) %>%
  arrange(country_code, year, hs_section_code)

# -----------------------------------------------------------
# 4. LOAD ECI DATA
# -----------------------------------------------------------

eci_raw <- read_csv(
  "data/raw/eci_mit.csv",
  show_col_types = FALSE
)

eci_clean <- eci_raw %>%
  filter(country_code %in% c("UZB", "VNM", "KAZ", "KOR", "CHN")) %>%
  select(
    country_code,
    country,
    year,
    eci,
    source,
    source_url
  ) %>%
  mutate(
    year = as.integer(year),
    eci = as.numeric(eci)
  ) %>%
  arrange(country_code, year)

# -----------------------------------------------------------
# 5. BASIC VALIDATION CHECKS
# -----------------------------------------------------------

required_year_min <- 2010
required_year_max <- 2023

validate_year_range <- function(data, data_name) {
  min_year <- min(data$year, na.rm = TRUE)
  max_year <- max(data$year, na.rm = TRUE)

  if (min_year > required_year_min || max_year < required_year_max) {
    warning(
      data_name,
      " does not cover the full target period ",
      required_year_min,
      "-",
      required_year_max,
      ". Observed range: ",
      min_year,
      "-",
      max_year
    )
  }
}

validate_year_range(wb_clean, "World Bank indicators")
validate_year_range(fdi_uzbek, "UzbekStat foreign investment data")
validate_year_range(exports_clean, "Export data")
validate_year_range(eci_clean, "ECI data")

# -----------------------------------------------------------
# 6. SAVE PROCESSED DATA
# -----------------------------------------------------------

saveRDS(wb_clean,      "data/processed/wb_indicators.rds")
saveRDS(fdi_uzbek,     "data/processed/fdi_uzbek.rds")
saveRDS(exports_clean, "data/processed/exports_comtrade.rds")
saveRDS(eci_clean,     "data/processed/eci_data.rds")

write_csv(wb_clean,      "data/processed/wb_indicators.csv")
write_csv(fdi_uzbek,     "data/processed/fdi_uzbek.csv")
write_csv(exports_clean, "data/processed/exports_comtrade.csv")
write_csv(eci_clean,     "data/processed/eci_data.csv")

# Write data cleaning log
sink("output/logs/data_cleaning_log.txt")
cat("DATA CLEANING LOG\n")
cat("Date:", format(Sys.Date()), "\n\n")
cat("World Bank:", nrow(wb_clean), "observations\n")
cat("Uzbek FDI:", nrow(fdi_uzbek), "observations\n")
cat("Comtrade/BACI exports:", nrow(exports_clean), "observations\n")
cat("ECI data:", nrow(eci_clean), "observations\n\n")
cat("Raw files preserved unmodified in data/raw/.\n")
cat("See data/raw/source_manifest.csv for source caveats.\n")
sink()

cat("\nData cleaning complete. Processed files saved.\n")
