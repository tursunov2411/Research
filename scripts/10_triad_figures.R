# ============================================================
# Script: 10_triad_figures.R
# Purpose: Generate Uzbekistan-Northeast Asia trade and
#          investment figures using actual public data sources.
# Sources:
#   - OEC/BACI public API for bilateral trade flows
#   - World Bank WDI API for trade openness
#   - OEC Economic Complexity data already stored locally
#   - National Statistics Committee of Uzbekistan for latest
#     investor-country shares in fixed-capital foreign
#     investment and loans
# ============================================================

source("scripts/00_setup.R")

OUTPUT_DIR <- "output/figures"
TABLE_DIR <- "output/tables"
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)
if (!dir.exists(TABLE_DIR)) dir.create(TABLE_DIR, recursive = TRUE)

REFORM_YEAR <- 2017
YEARS <- 2010:2023
UZB_OEC <- "uzb"
PARTNERS <- c("chn" = "China", "jpn" = "Japan", "kor" = "South Korea")

CLR_CHINA <- "#1a6b8a"
CLR_JAPAN <- "#c0392b"
CLR_KOREA <- "#27ae60"
CLR_UZB <- "#e67e22"
CLR_REFORM <- "#e67e22"
CLR_NEUTRAL <- "#7f8c8d"

partner_palette <- c(
  "China" = CLR_CHINA,
  "Japan" = CLR_JAPAN,
  "South Korea" = CLR_KOREA
)

theme_triad <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(color = "grey40", size = 10),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold")
  )

fetch_json <- function(url) {
  jsonlite::fromJSON(url)
}

oec_url <- function(cube, drilldowns, measures, filters) {
  params <- c(
    list(
      cube = cube,
      drilldowns = paste(drilldowns, collapse = ","),
      measures = paste(measures, collapse = ",")
    ),
    filters
  )

  query <- paste(
    paste(
      vapply(names(params), utils::URLencode, character(1), reserved = TRUE),
      vapply(params, utils::URLencode, character(1), reserved = TRUE),
      sep = "="
    ),
    collapse = "&"
  )

  paste0(
    "https://api.oec.world/tesseract/data.jsonrecords?",
    query
  )
}

fetch_oec_trade <- function(exporter, importer, years, include_section = FALSE) {
  drilldowns <- c("Year", "Exporter Country Official", "Importer Country Official")
  if (include_section) {
    drilldowns <- c(drilldowns, "Section Official")
  }

  url <- oec_url(
    cube = "trade_i_baci_a_92",
    drilldowns = drilldowns,
    measures = "Trade Value",
    filters = list(
      "Exporter Country Official" = exporter,
      "Importer Country Official" = importer,
      "Year" = paste(years, collapse = ",")
    )
  )

  data <- fetch_json(url)$data
  if (length(data) == 0) {
    return(tibble())
  }

  tibble::as_tibble(data) %>%
    rename_with(~ gsub("_+", "_", gsub("[^A-Za-z0-9]+", "_", tolower(.x)))) %>%
    mutate(source_url = url)
}

save_fig <- function(plot, stem, width = 10, height = 6) {
  png_path <- file.path(OUTPUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUTPUT_DIR, paste0(stem, ".pdf"))

  ggsave(png_path, plot = plot, width = width, height = height, dpi = 300, bg = "white")
  ggsave(pdf_path, plot = plot, width = width, height = height, device = cairo_pdf, bg = "white")

  message("Saved: ", png_path)
  message("Saved: ", pdf_path)
}

message("\n========================================")
message("Generating triad figures from actual sources")
message("========================================")

# ------------------------------------------------------------
# Bilateral trade series from OEC/BACI
# ------------------------------------------------------------

bilateral_trade <- purrr::imap_dfr(
  PARTNERS,
  function(partner_name, partner_id) {
    exports <- fetch_oec_trade(UZB_OEC, partner_id, YEARS) %>%
      transmute(year, partner = partner_name, exports_usd = trade_value)

    imports <- fetch_oec_trade(partner_id, UZB_OEC, YEARS) %>%
      transmute(year, partner = partner_name, imports_usd = trade_value)

    full_join(exports, imports, by = c("year", "partner")) %>%
      mutate(
        exports_usd = coalesce(exports_usd, 0),
        imports_usd = coalesce(imports_usd, 0),
        trade_balance_usd = exports_usd - imports_usd,
        total_trade_usd = exports_usd + imports_usd
      )
  }
) %>%
  arrange(partner, year)

write_csv(bilateral_trade, file.path(TABLE_DIR, "table_triad_bilateral_trade.csv"))

max_trade_billions <- max(bilateral_trade$total_trade_usd / 1e9, na.rm = TRUE)

p7a <- bilateral_trade %>%
  ggplot(aes(year, total_trade_usd / 1e9, colour = partner, group = partner)) +
  geom_vline(
    xintercept = REFORM_YEAR,
    linetype = "dashed",
    colour = CLR_REFORM,
    linewidth = 0.8
  ) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  annotate(
    "text",
    x = REFORM_YEAR + 0.3,
    y = max_trade_billions * 0.95,
    label = "2017 Reform",
    colour = CLR_REFORM,
    hjust = 0,
    size = 3.2
  ) +
  scale_colour_manual(values = partner_palette) +
  scale_y_continuous(labels = scales::label_dollar(suffix = "B")) +
  labs(
    x = NULL,
    y = "USD Billion",
    colour = NULL
  ) +
  theme_triad

p7b <- bilateral_trade %>%
  ggplot(aes(year, trade_balance_usd / 1e9, colour = partner, group = partner)) +
  geom_hline(yintercept = 0, linetype = "solid", colour = "grey60") +
  geom_vline(
    xintercept = REFORM_YEAR,
    linetype = "dashed",
    colour = CLR_REFORM,
    linewidth = 0.8
  ) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_colour_manual(values = partner_palette) +
  scale_y_continuous(labels = scales::label_dollar(suffix = "B")) +
  labs(
    x = "Year",
    y = "USD Billion",
    colour = NULL
  ) +
  theme_triad

fig7 <- (p7a / p7b) +
  patchwork::plot_annotation(
    caption = paste(
      "Source: OEC/BACI public API, bilateral merchandise trade values in current USD.",
      "Trade totals and balances are author calculations from exporter-importer flows."
    ),
    theme = theme(plot.title = element_text(face = "bold", size = 13))
  )

save_fig(fig7, "fig7_bilateral_trade", width = 10, height = 7)

# ------------------------------------------------------------
# Figure 8 uses the latest official investor-country share
# snapshot because a public annual bilateral FDI flow API by
# source country is not available for Uzbekistan.
# Source:
# https://stat.uz/img/investitsiya-ang_p45964.pdf
# ------------------------------------------------------------

fdi_country_shares_2024 <- tibble(
  country = c(
    "China",
    "Russia",
    "Turkey",
    "Germany",
    "Saudi Arabia",
    "Netherlands",
    "United Arab Emirates",
    "Great Britain"
  ),
  share_pct = c(27.9, 13.2, 6.8, 5.2, 5.0, 4.0, 3.9, 3.7)
) %>%
  arrange(desc(share_pct))

write_csv(fdi_country_shares_2024, file.path(TABLE_DIR, "table_fdi_country_shares_2024.csv"))

fig8 <- fdi_country_shares_2024 %>%
  ggplot(aes(x = reorder(country, share_pct), y = share_pct, fill = country == "China")) +
  geom_col(width = 0.7, alpha = 0.9, show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = CLR_CHINA, "FALSE" = CLR_NEUTRAL)) +
  scale_y_continuous(labels = scales::label_percent(scale = 1), expand = expansion(mult = c(0, 0.05))) +
  labs(
    x = NULL,
    y = "Share of Total (%)",
    caption = paste(
      "Source: National Statistics Committee of Uzbekistan,",
      "Investments in Fixed Capital in the Republic of Uzbekistan (January-December 2024).",
      "Japan and South Korea were not disclosed among the reported top investor countries in this release."
    )
  ) +
  theme_triad

save_fig(fig8, "fig8_fdi_by_origin", width = 9, height = 5.5)

# ------------------------------------------------------------
# Intermediate-goods import share from OEC/BACI section data
# Proxy sections for manufacturing inputs:
#   07 Plastics and Rubbers
#   15 Metals
#   16 Machines
#   17 Transportation
#   18 Instruments
# ------------------------------------------------------------

intermediate_section_ids <- c("07", "15", "16", "17", "18")

triad_import_sections <- purrr::imap_dfr(
  PARTNERS,
  function(partner_name, partner_id) {
    fetch_oec_trade(partner_id, UZB_OEC, YEARS, include_section = TRUE) %>%
      transmute(
        year,
        partner = partner_name,
        section_id = section_official_id,
        section = section_official,
        trade_value_usd = trade_value
      )
  }
)

intermediate_shares <- triad_import_sections %>%
  group_by(year, partner) %>%
  summarise(
    total_imports_usd = sum(trade_value_usd, na.rm = TRUE),
    intermediate_imports_usd = sum(
      trade_value_usd[section_id %in% intermediate_section_ids],
      na.rm = TRUE
    ),
    share_intermediate = intermediate_imports_usd / total_imports_usd,
    .groups = "drop"
  )

write_csv(intermediate_shares, file.path(TABLE_DIR, "table_intermediate_goods_share.csv"))

fig9 <- intermediate_shares %>%
  ggplot(aes(year, share_intermediate, colour = partner, group = partner, shape = partner)) +
  geom_vline(
    xintercept = REFORM_YEAR,
    linetype = "dashed",
    colour = CLR_REFORM,
    linewidth = 0.9
  ) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.8) +
  annotate(
    "text",
    x = REFORM_YEAR + 0.3,
    y = max(intermediate_shares$share_intermediate, na.rm = TRUE) * 0.98,
    label = "2017 Reform",
    colour = CLR_REFORM,
    hjust = 0,
    size = 3.2
  ) +
  scale_colour_manual(values = partner_palette) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  labs(
    x = "Year",
    y = "Intermediate Goods Share of Imports (%)",
    colour = NULL,
    shape = NULL,
    caption = paste(
      "Source: OEC/BACI public API.",
      "Intermediate goods are proxied by HS sections 07, 15, 16, 17, and 18."
    )
  ) +
  theme_triad

save_fig(fig9, "fig9_intermediate_goods_share", width = 10, height = 6)

# ------------------------------------------------------------
# Mechanism figure: actual trade openness, manufacturing VA, ECI
# ------------------------------------------------------------

wb_openness <- WDI::WDI(
  country = "UZB",
  indicator = "NE.TRD.GNFS.ZS",
  start = min(YEARS),
  end = max(YEARS),
  extra = TRUE
) %>%
  transmute(
    year,
    trade_open_pct_gdp = NE.TRD.GNFS.ZS
  )

wb_data <- readRDS("data/processed/wb_indicators.rds")
eci_data <- readRDS("data/processed/eci_data.rds")

mechanism_data <- wb_data %>%
  filter(country_code == "UZB", year %in% YEARS) %>%
  select(year, manuf_va_pct_gdp = manuf_va_gdp) %>%
  left_join(wb_openness, by = "year") %>%
  left_join(
    eci_data %>%
      filter(country_code == "UZB", year %in% YEARS) %>%
      select(year, eci),
    by = "year"
  ) %>%
  arrange(year) %>%
  mutate(
    trade_openness_idx = trade_open_pct_gdp / trade_open_pct_gdp[year == 2010] * 100,
    label = case_when(
      year %in% c(2010, 2016, 2023) ~ as.character(year),
      year == REFORM_YEAR ~ "2017\n(Reform)",
      TRUE ~ ""
    )
  )

write_csv(mechanism_data, file.path(TABLE_DIR, "table_mechanism_data.csv"))

label_layer <- if (requireNamespace("ggrepel", quietly = TRUE)) {
  ggrepel::geom_text_repel(
    data = filter(mechanism_data, label != ""),
    aes(label = label),
    size = 3,
    colour = "grey20",
    box.padding = 0.4,
    show.legend = FALSE
  )
} else {
  geom_text(
    data = filter(mechanism_data, label != ""),
    aes(label = label),
    size = 3,
    colour = "grey20",
    nudge_y = 0.25,
    show.legend = FALSE
  )
}

fig10 <- ggplot(
  mechanism_data,
  aes(trade_openness_idx, manuf_va_pct_gdp, colour = eci, size = -eci)
) +
  geom_path(
    data = mechanism_data,
    aes(x = trade_openness_idx, y = manuf_va_pct_gdp),
    inherit.aes = FALSE,
    colour = "grey60",
    linewidth = 0.8,
    show.legend = FALSE
  ) +
  geom_point(alpha = 0.9) +
  label_layer +
  scale_colour_gradient2(
    low = "#c0392b",
    mid = "#f39c12",
    high = "#27ae60",
    midpoint = median(mechanism_data$eci, na.rm = TRUE),
    name = "ECI Score"
  ) +
  scale_size_continuous(range = c(3, 8), guide = "none") +
  labs(
    x = "Trade Openness Index (2010 = 100)",
    y = "Manufacturing VA (% of GDP)",
    caption = paste(
      "Source: World Bank WDI (trade openness and manufacturing value added) and OEC Economic Complexity data.",
      "Trade openness index is derived from NE.TRD.GNFS.ZS with 2010 normalized to 100."
    )
  ) +
  theme_triad +
  theme(legend.position = "right")

save_fig(fig10, "fig10_mechanism_trajectory", width = 9.5, height = 6)

# ------------------------------------------------------------
# Post-reform growth decomposition from actual bilateral trade
# ------------------------------------------------------------

growth_decomp <- bilateral_trade %>%
  filter(year %in% c(2016, 2023)) %>%
  select(year, partner, total_trade_usd) %>%
  tidyr::pivot_wider(names_from = year, values_from = total_trade_usd, names_prefix = "y") %>%
  mutate(
    abs_growth_usd = y2023 - y2016,
    pct_growth = (y2023 - y2016) / y2016 * 100,
    share_growth = abs_growth_usd / sum(abs_growth_usd) * 100
  )

write_csv(growth_decomp, file.path(TABLE_DIR, "table_growth_decomposition.csv"))

fig11 <- growth_decomp %>%
  select(partner, pct_growth, share_growth) %>%
  tidyr::pivot_longer(c(pct_growth, share_growth), names_to = "metric", values_to = "value") %>%
  mutate(
    metric = dplyr::recode(
      metric,
      pct_growth = "% Growth 2016-2023",
      share_growth = "Share of Total Trade Growth (%)"
    )
  ) %>%
  ggplot(aes(partner, value, fill = partner)) +
  geom_col(width = 0.6, alpha = 0.9) +
  geom_text(aes(label = round(value, 1)), vjust = -0.4, size = 3.5) +
  facet_wrap(~metric, scales = "free_y") +
  scale_fill_manual(values = partner_palette, guide = "none") +
  labs(
    x = NULL,
    y = NULL,
    caption = "Source: OEC/BACI public API. Growth shares are author calculations."
  ) +
  theme_triad

save_fig(fig11, "fig11_growth_decomposition", width = 10, height = 6)

message("\n========================================")
message("All figures saved to: ", OUTPUT_DIR)
message("Figures generated from actual public sources:")
message("  fig7  - Bilateral trade flows UZB <-> China/Japan/South Korea")
message("  fig8  - Latest official investor-country shares in foreign investment")
message("  fig9  - Intermediate goods share of imports from triad partners")
message("  fig10 - Trade openness, manufacturing VA, and ECI trajectory")
message("  fig11 - Post-reform trade growth decomposition")
message("========================================\n")
