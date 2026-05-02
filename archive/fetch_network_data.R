# =============================================================================
# fetch_network_data.R
# Pull REAL bilateral trade data for Trade Network Analysis
# Sources: OEC/BACI API, World Bank WDI, OECD TiVA (proxy via WB)
# Outputs: data/raw/network_*.csv (timestamped), updated source_manifest.csv
# Run: Rscript fetch_network_data.R
# =============================================================================

# ── 0. Dependencies ────────────────────────────────────────────────────────────
pkgs <- c("httr", "jsonlite", "dplyr", "tidyr", "readr", "wbstats", "lubridate", "purrr")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "http://cran.us.r-project.org")
  library(p, character.only = TRUE)
}))

RAW_DIR  <- "data/raw"
PROC_DIR <- "data/processed"
dir.create(RAW_DIR,  showWarnings = FALSE, recursive = TRUE)
dir.create(PROC_DIR, showWarnings = FALSE, recursive = TRUE)

FETCH_DATE <- format(Sys.Date(), "%Y-%m-%d")
LOG <- character()
log_msg <- function(msg) { cat(msg, "\n"); LOG <<- c(LOG, msg) }

# ── helper: save + log ─────────────────────────────────────────────────────────
save_raw <- function(df, name, source, note) {
  fname <- file.path(RAW_DIR, paste0(name, ".csv"))
  write_csv(df, fname)
  log_msg(paste("  Saved:", fname, "(", nrow(df), "rows )"))
  list(file = paste0(name, ".csv"), status = "fetched", source = source,
       note = note, fetch_date = FETCH_DATE, rows = nrow(df))
}

manifest_entries <- list()

# =============================================================================
# 1. OEC BACI API — Bilateral IMPORTS: CHN/JPN/KOR → UZB by HS Section
#    Endpoint: https://api.oec.world/tesseract/data.jsonrecords
#    Cube: trade_i_baci_a_92   (annual, HS1992)
#    Dimensions: Year, Exporter ISO3, Importer ISO3, HS Section
# =============================================================================
log_msg("\n[1] Fetching bilateral imports (OEC BACI) CHN/JPN/KOR → UZB by HS Section ...")

OEC_BASE <- "https://api.oec.world/tesseract/data.jsonrecords"

# HS section mappings (HS 1992, sections 01-21)
hs_section_labels <- c(
  "01"="Animal Products","02"="Vegetable Products","03"="Animal & Veg Bi-Products",
  "04"="Foodstuffs","05"="Mineral Products","06"="Chemical Products",
  "07"="Plastics & Rubbers","08"="Animal Hides","09"="Wood Products",
  "10"="Paper Goods","11"="Textiles","12"="Footwear & Headwear",
  "13"="Stone & Glass","14"="Precious Metals","15"="Metals",
  "16"="Machines","17"="Transportation","18"="Instruments",
  "19"="Weapons","20"="Miscellaneous","21"="Arts & Antiques"
)

# BEC Rev. 5 classification: Intermediate goods HS sections
# Sections 07 (Plastics), 15 (Metals), 16 (Machines), 17 (Transportation), 18 (Instruments)
# Also 05 (Mineral Products/energy inputs), 06 (Chemicals) partially intermediate
INTERMEDIATE_SECTIONS <- c("05", "06", "07", "15", "16", "17", "18")
CAPITAL_SECTIONS      <- c("16", "17", "18")
PRIMARY_SECTIONS      <- c("01", "02", "03", "04", "05", "08", "09", "13", "14")
CONSUMER_SECTIONS     <- c("04", "10", "11", "12", "20", "21")

fetch_oec_bilateral <- function(exporter_iso3, importer_iso3, years = 2010:2023) {
  results <- list()
  for (yr in years) {
    url <- paste0(OEC_BASE,
      "?cube=trade_i_baci_a_92",
      "&drilldowns=Year,HS%20Section,Exporter+Country,Importer+Country",
      "&measures=Trade+Value",
      "&Year=", yr,
      "&Exporter+Country=", exporter_iso3,
      "&Importer+Country=", importer_iso3,
      "&locale=en"
    )
    resp <- tryCatch(GET(url, timeout(30)), error = function(e) NULL)
    if (is.null(resp) || status_code(resp) != 200) {
      log_msg(paste("    WARNING: Failed", exporter_iso3, "->", importer_iso3, yr))
      next
    }
    parsed <- tryCatch(fromJSON(content(resp, "text", encoding = "UTF-8")), error = function(e) NULL)
    if (is.null(parsed) || is.null(parsed$data) || length(parsed$data) == 0) next
    df <- as.data.frame(parsed$data)
    if (!"Trade Value" %in% names(df)) next
    df <- df %>%
      rename_with(~ gsub(" ", "_", .x)) %>%
      mutate(
        exporter = exporter_iso3,
        importer = importer_iso3,
        year     = as.integer(yr),
        trade_value_usd = as.numeric(Trade_Value)
      )
    results[[length(results)+1]] <- df
    Sys.sleep(0.3)   # polite rate limiting
  }
  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

pairs <- list(
  list(exp = "CHN", imp = "UZB", label = "China→UZB"),
  list(exp = "JPN", imp = "UZB", label = "Japan→UZB"),
  list(exp = "KOR", imp = "UZB", label = "SKorea→UZB"),
  list(exp = "UZB", imp = "CHN", label = "UZB→China"),
  list(exp = "UZB", imp = "JPN", label = "UZB→Japan"),
  list(exp = "UZB", imp = "KOR", label = "UZB→SKorea"),
  # Re-export potential: UZB exports to Central Asia neighbours
  list(exp = "UZB", imp = "KAZ", label = "UZB→Kazakhstan"),
  list(exp = "UZB", imp = "RUS", label = "UZB→Russia"),
  list(exp = "UZB", imp = "TUR", label = "UZB→Turkey")
)

all_bilateral <- list()
for (p in pairs) {
  log_msg(paste("  Fetching:", p$label))
  d <- fetch_oec_bilateral(p$exp, p$imp)
  if (!is.null(d) && nrow(d) > 0) {
    d$direction <- p$label
    all_bilateral[[length(all_bilateral)+1]] <- d
  }
}

if (length(all_bilateral) > 0) {
  bilateral_raw <- bind_rows(all_bilateral) %>%
    mutate(
      hs_section_code = sprintf("%02d", as.integer(gsub("[^0-9]", "", HS_Section))),
      hs_section_label = hs_section_labels[hs_section_code],
      good_type = case_when(
        hs_section_code %in% CAPITAL_SECTIONS      ~ "Capital/Machines",
        hs_section_code %in% INTERMEDIATE_SECTIONS ~ "Other Intermediate",
        hs_section_code %in% PRIMARY_SECTIONS       ~ "Primary Commodity",
        hs_section_code %in% CONSUMER_SECTIONS     ~ "Consumer Good",
        TRUE                                        ~ "Other"
      ),
      is_intermediate = hs_section_code %in% INTERMEDIATE_SECTIONS,
      source_url = OEC_BASE,
      fetch_date = FETCH_DATE
    ) %>%
    select(year, exporter, importer, direction, hs_section_code, hs_section_label,
           trade_value_usd, good_type, is_intermediate, source_url, fetch_date)

  manifest_entries[[length(manifest_entries)+1]] <- save_raw(
    bilateral_raw, "network_bilateral_hs",
    "OEC/BACI HS1992 API",
    "Bilateral trade by HS section (21 sections), UZB<->CHN/JPN/KOR + re-export destinations. BEC classification applied."
  )
} else {
  log_msg("  WARNING: OEC API returned no data. Check connectivity / API availability.")
  bilateral_raw <- NULL
}

# =============================================================================
# 2. World Bank WDI — Macro indicators for network analysis
#    New indicators: Value Added by sector, tariff rates, logistics
# =============================================================================
log_msg("\n[2] Fetching World Bank WDI indicators (extended set) ...")

wb_indicators_extended <- c(
  # Manufacturing & industry
  "NV.IND.MANF.ZS"   = "mfg_va_pct_gdp",
  "NV.IND.MANF.CD"   = "mfg_va_usd",
  "NV.IND.TOTL.ZS"   = "industry_va_pct_gdp",
  "NV.SRV.TOTL.ZS"   = "services_va_pct_gdp",
  # Trade
  "NE.TRD.GNFS.ZS"   = "trade_openness",
  "TX.VAL.MRCH.CD.WT" = "merch_exports_usd",
  "TM.VAL.MRCH.CD.WT" = "merch_imports_usd",
  "TX.VAL.MANF.ZS.UN" = "manuf_exports_pct",
  # FDI
  "BX.KLT.DINV.WD.GD.ZS" = "fdi_pct_gdp",
  "BX.KLT.DINV.CD.WD"    = "fdi_usd",
  # GDP
  "NY.GDP.PCAP.CD"   = "gdp_pc_usd",
  "NY.GDP.MKTP.CD"   = "gdp_usd",
  "NY.GDP.MKTP.KD.ZG"= "gdp_growth",
  # Logistics & infrastructure
  "LP.LPI.OVRL.XQ"   = "lpi_score",
  "IS.RRS.TOTL.KM"   = "rail_km",
  # Labour
  "SL.UEM.TOTL.ZS"   = "unemployment_pct",
  "SL.IND.EMPL.ZS"   = "industry_employment_pct",
  "SL.MNF.EMPL.ZS"   = "manufacturing_employment_pct"
)

wb_countries <- c("UZ", "CN", "JP", "KR", "VN", "KZ", "TJ", "TM", "KG")

wb_raw <- tryCatch({
  wb_data(
    indicator = names(wb_indicators_extended),
    country   = wb_countries,
    start_date = 2005,
    end_date   = 2024,
    return_wide = TRUE
  )
}, error = function(e) {
  log_msg(paste("  WARNING wbstats:", e$message))
  NULL
})

if (!is.null(wb_raw) && nrow(wb_raw) > 0) {
  # Rename indicator columns to friendly names
  wb_clean <- wb_raw %>%
    rename_with(~ {
      m <- match(.x, names(wb_indicators_extended))
      ifelse(!is.na(m), wb_indicators_extended[m], .x)
    }) %>%
    rename(year = date, iso2 = iso2c, iso3 = iso3c) %>%
    mutate(year = as.integer(year), fetch_date = FETCH_DATE)

  manifest_entries[[length(manifest_entries)+1]] <- save_raw(
    wb_clean, "network_wb_extended",
    "World Bank WDI API (wbstats)",
    paste("Extended macro panel:", length(wb_indicators_extended), "indicators, 9 countries, 2005-2024.")
  )
} else {
  log_msg("  WARNING: WB WDI fetch failed.")
  wb_clean <- NULL
}

# =============================================================================
# 3. OECD TiVA Proxy — Foreign Value Added in Exports
#    OECD TiVA API requires token; use WB proxy: TX.VAL.TECH.MF.ZS (tech exports)
#    + estimate DVA/FVA ratio from available WB data
#    Real TiVA table: https://stats.oecd.org/SDMX-JSON/data/TIVA_2023_C1/...
# =============================================================================
log_msg("\n[3] Fetching OECD TiVA data (SDMX-JSON endpoint, no auth required for C1 table)...")

# TiVA 2023 C1: Backward GVC participation: Foreign Value Added in Gross Exports (%)
# We query for UZB and Central Asian comparators
tiva_url <- function(country, measure = "EXGR_FVASH") {
  paste0(
    "https://stats.oecd.org/SDMX-JSON/data/TIVA_2023_C1/",
    country, ".TOT_B1G.", measure, "/all",
    "?contentType=csv&detail=code&startPeriod=2010&endPeriod=2020"
  )
}

tiva_countries <- c("UZB", "VNM", "KAZ", "KGZ", "BGD", "PAK")
tiva_measures  <- c(
  "EXGR_FVASH" = "fva_share_exports_pct",    # Foreign VA as % of gross exports
  "EXGR_DVASH" = "dva_share_exports_pct",    # Domestic VA as % of gross exports
  "IMGR_FVASH" = "fva_share_imports_pct"     # Foreign VA in imports
)

tiva_results <- list()
for (ctry in tiva_countries) {
  for (meas in names(tiva_measures)) {
    url <- tiva_url(ctry, meas)
    resp <- tryCatch(GET(url, timeout(30)), error = function(e) NULL)
    if (is.null(resp)) next
    if (status_code(resp) == 200) {
      ct <- content(resp, "text", encoding = "UTF-8")
      # CSV response
      df <- tryCatch(read_csv(ct, show_col_types = FALSE), error = function(e) NULL)
      if (!is.null(df) && nrow(df) > 0) {
        df$country_code <- ctry
        df$measure <- meas
        df$measure_label <- tiva_measures[meas]
        tiva_results[[length(tiva_results)+1]] <- df
        log_msg(paste("    TiVA OK:", ctry, meas))
      }
    } else {
      log_msg(paste("    TiVA miss:", ctry, meas, "HTTP", status_code(resp)))
    }
    Sys.sleep(0.5)
  }
}

if (length(tiva_results) > 0) {
  tiva_raw <- bind_rows(tiva_results) %>%
    mutate(fetch_date = FETCH_DATE)
  manifest_entries[[length(manifest_entries)+1]] <- save_raw(
    tiva_raw, "network_tiva_oecd",
    "OECD TiVA 2023 (SDMX-JSON TIVA_2023_C1)",
    paste("FVA/DVA shares in gross exports/imports.", length(tiva_countries), "countries.")
  )
} else {
  log_msg("  NOTE: OECD TiVA API returned no data (may not cover UZB). Fallback: WB proxy will be used in processing step.")
  # Save a placeholder so the manifest notes this
  tiva_placeholder <- tibble(
    note = "OECD TiVA 2023 does not include Uzbekistan. Use WB TX.VAL.TECH.MF.ZS and FVA proxies.",
    fetch_date = FETCH_DATE
  )
  manifest_entries[[length(manifest_entries)+1]] <- save_raw(
    tiva_placeholder, "network_tiva_placeholder",
    "OECD TiVA 2023 — N/A for UZB",
    "UZB not covered. Proxy constructed from WB data in process_network_data.R."
  )
}

# =============================================================================
# 4. OEC API — Re-export potential: UZB exports to Central Asia & beyond
#    What does UZB export, and how much of it is re-processed Chinese imports?
# =============================================================================
log_msg("\n[4] Fetching UZB export composition by destination (re-export map)...")

reexport_destinations <- c("KAZ", "RUS", "TUR", "DEU", "GBR", "CHN", "AFG", "TJK")
reexport_data <- list()

for (dest in reexport_destinations) {
  log_msg(paste("  Fetching UZB→", dest))
  d <- fetch_oec_bilateral("UZB", dest, years = 2015:2023)
  if (!is.null(d) && nrow(d) > 0) {
    d$direction <- paste0("UZB→", dest)
    reexport_data[[length(reexport_data)+1]] <- d
  }
}

if (length(reexport_data) > 0) {
  reexport_raw <- bind_rows(reexport_data) %>%
    mutate(
      hs_section_code = sprintf("%02d", as.integer(gsub("[^0-9]", "", HS_Section))),
      good_type = case_when(
        hs_section_code %in% CAPITAL_SECTIONS      ~ "Capital/Machines",
        hs_section_code %in% INTERMEDIATE_SECTIONS ~ "Intermediate",
        hs_section_code %in% PRIMARY_SECTIONS      ~ "Primary Commodity",
        TRUE                                       ~ "Consumer/Other"
      ),
      # Flag potential re-exports: manufactures + machines exported to non-NE Asia
      is_potential_reexport = good_type %in% c("Capital/Machines", "Intermediate") &
                              importer %in% c("KAZ", "RUS", "TUR", "DEU", "GBR"),
      fetch_date = FETCH_DATE
    )
  manifest_entries[[length(manifest_entries)+1]] <- save_raw(
    reexport_raw, "network_reexport_map",
    "OEC/BACI HS1992 API",
    paste("UZB exports to", length(reexport_destinations), "destinations for re-export potential analysis, 2015-2023.")
  )
} else {
  log_msg("  WARNING: Re-export data fetch failed.")
  reexport_raw <- NULL
}

# =============================================================================
# 5. Update source_manifest.csv
# =============================================================================
log_msg("\n[5] Updating source_manifest.csv ...")

manifest_path <- file.path(RAW_DIR, "source_manifest.csv")
existing_manifest <- tryCatch(read_csv(manifest_path, show_col_types = FALSE),
                              error = function(e) tibble())

new_entries <- bind_rows(lapply(manifest_entries, as_tibble))
# Remove old entries for same filenames then append new
updated_manifest <- bind_rows(
  existing_manifest %>% filter(!file %in% new_entries$file),
  new_entries
)
write_csv(updated_manifest, manifest_path)
log_msg(paste("  Manifest updated:", nrow(updated_manifest), "entries."))

# =============================================================================
# 6. Write fetch log
# =============================================================================
log_path <- file.path(RAW_DIR, paste0("fetch_log_", gsub("-", "", FETCH_DATE), ".txt"))
writeLines(LOG, log_path)

cat("\n========================================\n")
cat("FETCH COMPLETE —", FETCH_DATE, "\n")
cat("Raw files in:", RAW_DIR, "\n")
cat("Log:", log_path, "\n")
cat("Next step: Rscript process_network_data.R\n")
cat("========================================\n")
