# Fetch bilateral trade data using UN Comtrade API via comtradr package
# This script fetches total trade (exports and imports) between Uzbekistan and China, Japan, South Korea
# from 2010 to 2023

# Install required packages if not already installed
if (!require(comtradr)) install.packages("comtradr")
if (!require(dplyr)) install.packages("dplyr")
if (!require(readr)) install.packages("readr")

library(comtradr)
library(dplyr)
library(readr)

# Set API key if you have one (optional, but recommended for higher limits)
# Sys.setenv("COMTRADE_API_KEY" = "your_api_key_here")

# Function to fetch trade data
fetch_trade <- function(reporter, partner, flow, start_year, end_year) {
  tryCatch({
    data <- ct_get_data(
      reporter = reporter,
      partner = partner,
      start_date = start_year,
      end_date = end_year,
      flow_direction = "export",  # Always "export" since we're fetching export data
      frequency = "A"  # Annual
    )
    return(data)
  }, error = function(e) {
    message("Error fetching data for ", reporter, " -> ", partner, " (", flow, "): ", e$message)
    return(NULL)
  })
}

# Fetch exports from UZB to triad countries
exports_uzb <- bind_rows(
  fetch_trade("UZB", "CHN", "X", 2012, 2023),
  fetch_trade("UZB", "JPN", "X", 2012, 2023),
  fetch_trade("UZB", "KOR", "X", 2012, 2023)
)

# Fetch imports to UZB from triad countries (exports from triad to UZB)
imports_uzb <- bind_rows(
  fetch_trade("CHN", "UZB", "X", 2012, 2023),
  fetch_trade("JPN", "UZB", "X", 2012, 2023),
  fetch_trade("KOR", "UZB", "X", 2012, 2023)
)

# Process exports
exports_processed <- exports_uzb %>%
  filter(!is.na(trade_value_usd)) %>%
  group_by(year = period, partner = partner_desc) %>%
  summarise(exports_mn_usd = sum(trade_value_usd, na.rm = TRUE) / 1e6, .groups = "drop") %>%
  mutate(partner = case_when(
    partner == "China" ~ "China",
    partner == "Japan" ~ "Japan",
    partner == "Rep. of Korea" ~ "S. Korea",
    TRUE ~ partner
  ))

# Process imports
imports_processed <- imports_uzb %>%
  filter(!is.na(trade_value_usd)) %>%
  group_by(year = period, partner = partner_desc) %>%
  summarise(imports_mn_usd = sum(trade_value_usd, na.rm = TRUE) / 1e6, .groups = "drop") %>%
  mutate(partner = case_when(
    partner == "China" ~ "China",
    partner == "Japan" ~ "Japan",
    partner == "Rep. of Korea" ~ "S. Korea",
    TRUE ~ partner
  ))

# Combine exports and imports
baci_bilateral <- full_join(
  exports_processed,
  imports_processed,
  by = c("year", "partner")
) %>%
  mutate(
    exports_mn_usd = ifelse(is.na(exports_mn_usd), 0, exports_mn_usd),
    imports_mn_usd = ifelse(is.na(imports_mn_usd), 0, imports_mn_usd),
    trade_balance = exports_mn_usd - imports_mn_usd,
    total_trade = exports_mn_usd + imports_mn_usd,
    post_reform = year >= 2017
  ) %>%
  arrange(partner, year)

# Save to CSV
write_csv(baci_bilateral, "data/baci_bilateral_trade.csv")

message("Bilateral trade data saved to data/baci_bilateral_trade.csv")