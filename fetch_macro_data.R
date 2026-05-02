# Fetch macroeconomic data using wbstats
# For trade openness, manufacturing VA, ECI, etc.

library(wbstats)
library(dplyr)
library(readr)
library(countrycode)

# Indicators
indicators <- c(
  "NE.TRD.GNFS.ZS" = "trade_pct_gdp",  # Trade (% of GDP)
  "NV.IND.MANF.ZS" = "mfg_va_pct_gdp", # Manufacturing, value added (% of GDP)
  "NY.GDP.MKTP.CD" = "gdp_usd"         # GDP (current US$)
)

# Fetch data for Uzbekistan
uzb_data <- wb_data(
  indicator = names(indicators),
  country = "UZ",
  start_date = 2010,
  end_date = 2023
) %>%
  select(date, all_of(names(indicators))) %>%
  rename(year = date) %>%
  mutate(year = as.integer(year))

# Rename columns
uzb_data <- uzb_data %>%
  rename_with(~ indicators[.], .cols = names(indicators))

# For ECI, it's not in WB, need from OEC or other source.
# For now, use scaffold or fetch from web.

# Since ECI is from OEC, and no direct API, use scaffold for now.
# But to get actual, perhaps download from https://oec.world/en/profile/country/uzb

# For now, create a placeholder for ECI
eci_data <- tribble(
  ~year, ~eci,
  2010, -0.65,
  2012, -0.70,
  2014, -0.60,
  2016, -0.55,
  2017, -0.48,
  2018, -0.40,
  2019, -0.35,
  2020, -0.42,
  2021, -0.30,
  2022, -0.18,
  2023, -0.10
)

# Combine
macro_data <- left_join(uzb_data, eci_data, by = "year")

# Calculate trade openness index (2010 = 100)
base_trade <- macro_data %>% filter(year == 2010) %>% pull(trade_pct_gdp)
macro_data <- macro_data %>%
  mutate(trade_openness_idx = trade_pct_gdp / base_trade * 100)

# Save
write_csv(macro_data, "data/macro_data.csv")

message("Macro data saved to data/macro_data.csv")