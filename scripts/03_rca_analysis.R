# ============================================================
# Script: 03_rca_analysis.R
# Analysis: Revealed Comparative Advantage (Balassa Index)
# Formula: RCA_ij = (X_ij/X_iw) / (X_wj/X_ww)
# ============================================================

source("scripts/00_setup.R")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

exports <- readRDS("data/processed/exports_comtrade.rds")

# The fetched Comtrade proxy is HS-section-level OEC/BACI data.
# If the processed export file only contains Uzbekistan, add the
# Vietnam comparison extract so the RCA denominator is comparative
# rather than a single-country total.
if (n_distinct(exports$country_code) < 2 &&
    file.exists("data/raw/vietnam_comparison.csv")) {
  vnm_exports <- read_csv(
    "data/raw/vietnam_comparison.csv",
    show_col_types = FALSE
  ) %>%
    filter(dataset == "exports_by_hs_section") %>%
    transmute(
      country_code = country_code,
      country = country,
      year = as.integer(year),
      hs_section_code = case_when(
        variable == "Animal Products" ~ "01",
        variable == "Vegetable Products" ~ "02",
        variable == "Animal and Vegetable Bi-Products" ~ "03",
        variable == "Foodstuffs" ~ "04",
        variable == "Mineral Products" ~ "05",
        variable == "Chemical Products" ~ "06",
        variable == "Plastics and Rubbers" ~ "07",
        variable == "Animal Hides" ~ "08",
        variable == "Wood Products" ~ "09",
        variable == "Paper Goods" ~ "10",
        variable == "Textiles" ~ "11",
        variable == "Footwear and Headwear" ~ "12",
        variable == "Stone And Glass" ~ "13",
        variable == "Precious Metals" ~ "14",
        variable == "Metals" ~ "15",
        variable == "Machines" ~ "16",
        variable == "Transportation" ~ "17",
        variable == "Instruments" ~ "18",
        variable == "Weapons" ~ "19",
        variable == "Miscellaneous" ~ "20",
        variable == "Arts and Antiques" ~ "21",
        TRUE ~ NA_character_
      ),
      hs_section = variable,
      value_usd = as.numeric(value),
      source = source,
      source_url = NA_character_
    ) %>%
    filter(!is.na(hs_section_code))

  exports <- bind_rows(exports, vnm_exports)
}

# -------------------------------------------------------
# CALCULATE RCA INDEX
# -------------------------------------------------------

rca_results <- exports %>%
  filter(country_code %in% c("UZB", "VNM")) %>%
  group_by(year, country_code) %>%
  mutate(total_exports_country = sum(value_usd, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(year, hs_section_code) %>%
  mutate(total_exports_product = sum(value_usd, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(year) %>%
  mutate(total_world = sum(value_usd, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(
    export_share_country = value_usd / total_exports_country,
    export_share_world = total_exports_product / total_world,
    rca = export_share_country / export_share_world,
    has_rca = ifelse(
      rca > 1,
      "RCA > 1 (Comparative Advantage)",
      "RCA <= 1 (No Advantage)"
    )
  ) %>%
  select(
    country_code,
    country,
    year,
    hs_section_code,
    product = hs_section,
    value_usd,
    export_share_country,
    export_share_world,
    rca,
    has_rca
  )

# Focus on Uzbekistan
rca_uzb <- rca_results %>%
  filter(country_code == "UZB") %>%
  arrange(year, desc(rca))

# -------------------------------------------------------
# KEY FINDING: Is RCA diversifying over time?
# -------------------------------------------------------

manufacturing_sections <- c("11", "15", "16", "17", "18")

rca_diversification <- rca_uzb %>%
  group_by(year) %>%
  summarise(
    sectors_with_rca = sum(rca > 1, na.rm = TRUE),
    mean_rca_manuf = mean(
      rca[hs_section_code %in% manufacturing_sections],
      na.rm = TRUE
    ),
    .groups = "drop"
  )

write_csv(rca_results, "data/processed/rca_results.csv")
saveRDS(rca_results, "data/processed/rca_results.rds")
write_csv(rca_diversification, "output/tables/table_rca_diversification.csv")

# -------------------------------------------------------
# VISUALISATION: RCA Evolution
# -------------------------------------------------------

rca_top_sectors <- rca_uzb %>%
  filter(year %in% c(2015, 2018, 2020, 2022, 2023)) %>%
  group_by(year) %>%
  slice_max(order_by = rca, n = 10, with_ties = FALSE) %>%
  ungroup()

fig_rca_heatmap <- ggplot(
  rca_top_sectors,
  aes(x = factor(year), y = reorder(product, rca), fill = rca)
) +
  geom_tile(color = "white") +
  scale_fill_gradient2(
    low = "#EBF5FB",
    mid = "#3498DB",
    high = "#1B4F72",
    midpoint = 2,
    name = "RCA Index"
  ) +
  labs(
    title = "Figure 2. Revealed Comparative Advantage - Uzbekistan",
    subtitle = "Top export sections by RCA index, selected years",
    x = "Year",
    y = "Export Section",
    caption = paste0(
      "Source: Author's calculations based on OEC/BACI export data.\n",
      "RCA > 1 indicates revealed comparative advantage."
    )
  ) +
  theme(axis.text.y = element_text(size = 8))

ggsave(
  "output/figures/fig2_rca_heatmap.png",
  fig_rca_heatmap,
  width = 10,
  height = 7,
  dpi = 300,
  bg = "white"
)

fig_rca_manuf <- ggplot(
  filter(rca_uzb, hs_section_code %in% manufacturing_sections),
  aes(x = year, y = rca, color = product, group = product)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  geom_hline(
    yintercept = 1,
    linetype = "dashed",
    color = "red",
    alpha = 0.7
  ) +
  annotate(
    "text",
    x = 2015.5,
    y = 1.05,
    label = "RCA = 1 threshold",
    size = 3,
    color = "red"
  ) +
  labs(
    title = "Figure 3. Manufacturing-Related RCA Trends - Uzbekistan",
    subtitle = "Textiles, metals, machines, transportation, and instruments",
    x = "Year",
    y = "RCA Index",
    color = "Section",
    caption = "Source: Author's calculations based on OEC/BACI export data."
  )

ggsave(
  "output/figures/fig3_rca_manufacturing.png",
  fig_rca_manuf,
  width = 9,
  height = 5.5,
  dpi = 300,
  bg = "white"
)

cat("RCA Analysis complete.\n")
