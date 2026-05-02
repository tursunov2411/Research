# Process FDI bilateral data from UNCTAD
# Download from: https://unctadstat.unctad.org/wds/TableViewer/tableView.aspx?ReportId=96740
# Select bilateral FDI inflows, download as CSV, save as data/unctad_fdi_bilateral.csv

library(readr)
library(dplyr)

# Load the data (assuming downloaded)
# Note: Adjust column names based on actual CSV
fdi_raw <- read_csv("data/unctad_fdi_bilateral.csv")

# Assuming columns: Host, Home, Year, FDI_Inflow_USD_million
# Filter for Uzbekistan as host, and triad as home
fdi_bilateral <- fdi_raw %>%
  filter(Host == "Uzbekistan",
         Home %in% c("China", "Japan", "Korea, Republic of")) %>%
  select(year = Year,
         origin = Home,
         fdi_mn_usd = FDI_Inflow_USD_million) %>%
  mutate(origin = case_when(
    origin == "China" ~ "China",
    origin == "Japan" ~ "Japan",
    origin == "Korea, Republic of" ~ "S. Korea",
    TRUE ~ origin
  )) %>%
  arrange(origin, year)

# Save processed
write_csv(fdi_bilateral, "data/fdi_bilateral_processed.csv")

message("FDI data processed and saved to data/fdi_bilateral_processed.csv")