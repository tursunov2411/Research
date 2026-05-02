# install.packages(c("wbstats", "countrycode", "ggrepel"))
library(wbstats)
library(countrycode)
library(ggrepel)
library(dplyr)
library(ggplot2)
library(patchwork)
library(scales)
library(tidyr)
library(readr)

OUTPUT_DIR <- "figures"
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR)

REFORM_YEAR <- 2017
TRIAD <- c("CN", "JP", "KR")   # ISO2 codes
UZB   <- "UZ"

THEME_THESIS <- theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(color = "grey40", size = 10),
    plot.caption     = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    strip.text       = element_text(face = "bold")
  )

# Colour palette consistent with existing figures
CLR_CHINA  <- "#1a6b8a"
CLR_JAPAN  <- "#c0392b"
CLR_KOREA  <- "#27ae60"
CLR_UZB    <- "#e67e22"
CLR_REFORM <- "#e67e22"

save_fig <- function(p, name, w = 10, h = 6) {
  path <- file.path(OUTPUT_DIR, paste0(name, ".pdf"))
  ggsave(path, plot = p, width = w, height = h, device = cairo_pdf)
  message("Saved: ", path)
}

# =============================================================================
# FIG 7 — Bilateral Trade Flows: Uzbekistan ↔ CN/JP/KR (2010-2023)
# Data source: UN Comtrade via comtradr
# =============================================================================

# Load actual bilateral trade data
baci_bilateral <- read_csv("data/baci_bilateral_trade.csv") %>%
  mutate(
    trade_balance   = exports_mn_usd - imports_mn_usd,
    total_trade     = exports_mn_usd + imports_mn_usd,
    post_reform     = year >= REFORM_YEAR
  )

# Panel A: Total bilateral trade (stacked area)
p7a <- baci_bilateral %>%
  ggplot(aes(year, total_trade / 1000, colour = partner, group = partner)) +
  geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
             colour = CLR_REFORM, linewidth = 0.8) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  annotate("text", x = REFORM_YEAR + 0.3, y = 5.5,
           label = "2017 Reform", colour = CLR_REFORM,
           hjust = 0, size = 3.2) +
  scale_colour_manual(values = c("China" = CLR_CHINA,
                                 "Japan" = CLR_JAPAN,
                                 "S. Korea" = CLR_KOREA)) +
  scale_y_continuous(labels = label_dollar(suffix = "B")) +
  labs(
    title    = "A. Total Trade (Exports + Imports)",
    x        = NULL, y = "USD Billion",
    colour   = NULL
  ) +
  THEME_THESIS

# Panel B: Trade balance (deficit/surplus)
p7b <- baci_bilateral %>%
  ggplot(aes(year, trade_balance / 1000, colour = partner, group = partner)) +
  geom_hline(yintercept = 0, linetype = "solid", colour = "grey60") +
  geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
             colour = CLR_REFORM, linewidth = 0.8) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_colour_manual(values = c("China" = CLR_CHINA,
                                 "Japan" = CLR_JAPAN,
                                 "S. Korea" = CLR_KOREA)) +
  scale_y_continuous(labels = label_dollar(suffix = "B")) +
  labs(
    title  = "B. Trade Balance (Exports minus Imports)",
    x      = "Year", y = "USD Billion",
    colour = NULL
  ) +
  THEME_THESIS

fig7 <- (p7a / p7b) +
  plot_annotation(
    title    = "Figure 7. Uzbekistan Bilateral Trade with Northeast Asia Triad (2010–2023)",
    subtitle = "China, Japan, and South Korea; vertical dashed line marks 2017 liberalisation reform",
    caption  = "Source: Author calculations based on UN Comtrade data.\nData fetched using comtradr package.",
    theme    = theme(plot.title = element_text(face = "bold", size = 13))
  )

save_fig(fig7, "fig7_bilateral_trade")

# =============================================================================
# FIG 8 — FDI Inflows by Origin Country: CN / JP / KR → Uzbekistan
# Data source: UNCTAD bilateral FDI statistics
# =============================================================================

fdi_bilateral <- read_csv("data/fdi_bilateral_processed.csv")

fig8 <- fdi_bilateral %>%
  ggplot(aes(year, fdi_mn_usd, fill = origin)) +
  geom_col(position = "stack", width = 0.7, alpha = 0.9) +
  geom_vline(xintercept = REFORM_YEAR - 0.5, linetype = "dashed",
             colour = CLR_REFORM, linewidth = 0.9) +
  annotate("text", x = REFORM_YEAR - 0.4, y = 2300,
           label = "2017 Reform", colour = CLR_REFORM,
           hjust = 0, size = 3.2) +
  scale_fill_manual(values = c("China" = CLR_CHINA,
                               "Japan" = CLR_JAPAN,
                               "S. Korea" = CLR_KOREA)) +
  scale_y_continuous(labels = label_dollar(suffix = "M")) +
  scale_x_continuous(breaks = 2015:2023) +
  labs(
    title    = "Figure 8. FDI Inflows into Uzbekistan by Northeast Asian Origin (2015–2023)",
    subtitle = "Annual FDI flows from China, Japan, and South Korea; USD million",
    x        = "Year",
    y        = "FDI Inflow (USD Million)",
    fill     = NULL,
    caption  = "Source: UNCTAD bilateral FDI statistics.\nData processed from UNCTAD downloads."
  ) +
  THEME_THESIS

save_fig(fig8, "fig8_fdi_by_origin")

# =============================================================================
# FIG 9 — Intermediate Goods Trade: CN-JP-KR → UZB Manufacturing Inputs
# For now, using scaffold as HS-level data requires manual processing
# =============================================================================

# Scaffold: intermediate goods import shares (% of total imports from triad)
intermediate_shares <- tribble(
  ~year, ~partner,    ~share_intermediate,
  2010, "China",       0.38,
  2013, "China",       0.42,
  2016, "China",       0.44,
  2017, "China",       0.47,
  2019, "China",       0.52,
  2021, "China",       0.55,
  2023, "China",       0.58,
  2010, "Japan",       0.55,
  2013, "Japan",       0.57,
  2016, "Japan",       0.58,
  2017, "Japan",       0.61,
  2019, "Japan",       0.63,
  2021, "Japan",       0.64,
  2023, "Japan",       0.66,
  2010, "S. Korea",    0.48,
  2013, "S. Korea",    0.51,
  2016, "S. Korea",    0.52,
  2017, "S. Korea",    0.56,
  2019, "S. Korea",    0.59,
  2021, "S. Korea",    0.61,
  2023, "S. Korea",    0.63
)

fig9 <- intermediate_shares %>%
  ggplot(aes(year, share_intermediate, colour = partner,
             group = partner, shape = partner)) +
  geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
             colour = CLR_REFORM, linewidth = 0.9) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  annotate("text", x = REFORM_YEAR + 0.3, y = 0.68,
           label = "2017 Reform", colour = CLR_REFORM,
           hjust = 0, size = 3.2) +
  scale_colour_manual(values = c("China" = CLR_CHINA,
                                 "Japan" = CLR_JAPAN,
                                 "S. Korea" = CLR_KOREA)) +
  scale_y_continuous(labels = label_percent(), limits = c(0.3, 0.75)) +
  labs(
    title    = "Figure 9. Share of Intermediate Goods in Uzbekistan's Imports from Northeast Asia",
    subtitle = "Higher share signals deeper GVC integration; selected years 2010–2023",
    x        = "Year",
    y        = "Intermediate Goods Share of Imports (%)",
    colour   = NULL, shape = NULL,
    caption  = paste0(
      "Source: Author calculations from BACI HS-level bilateral trade data.\n",
      "Intermediate goods classified by BEC Rev.5 categories 1, 2, and 3.\n",
      "*** Replace scaffold data with actual HS-disaggregated BACI flows. ***"
    )
  ) +
  THEME_THESIS

save_fig(fig9, "fig9_intermediate_goods_share")

# =============================================================================
# FIG 10 — Four-Quadrant Mechanism Chart
# =============================================================================

# Load macro data
macro_data <- read_csv("data/macro_data.csv")

mechanism_data <- macro_data %>%
  select(year, trade_openness_idx, mfg_va_pct_gdp, eci) %>%
  mutate(label = case_when(
    year == 2010 ~ "2010",
    year == 2016 ~ "2016",
    year == 2017 ~ "2017\n(Reform)",
    year == 2023 ~ "2023",
    TRUE ~ ""
  ))

fig10 <- mechanism_data %>%
  ggplot(aes(trade_openness_idx, mfg_va_pct_gdp, colour = eci, size = -eci)) +
  geom_path(colour = "grey60", linewidth = 0.8, show.legend = FALSE) +
  geom_point(alpha = 0.9) +
  ggrepel::geom_text_repel(
    data = mechanism_data %>% filter(label != ""),
    aes(label = label), size = 3, colour = "grey20",
    box.padding = 0.4, show.legend = FALSE
  ) +
  scale_colour_gradient2(
    low = "#c0392b", mid = "#f39c12", high = "#27ae60",
    midpoint = -0.35,
    name = "ECI Score"
  ) +
  scale_size_continuous(range = c(3, 8), guide = "none") +
  labs(
    title    = "Figure 10. Trade Openness, Manufacturing VA, and ECI Trajectory (2010–2023)",
    subtitle = "Dot size and colour reflect ECI level (darker/larger = less complex); path traces time",
    x        = "Trade Openness Index (2010 = 100)",
    y        = "Manufacturing VA (% of GDP)",
    caption  = "Source: World Bank WDI and OEC Economic Complexity data. Trade openness = (X+M)/GDP indexed."
  ) +
  THEME_THESIS +
  theme(legend.position = "right")

save_fig(fig10, "fig10_mechanism_trajectory")

# =============================================================================
# FIG 11 — Reform-Aligned Decomposition: Post-2017 Trade Growth by Partner
# =============================================================================

growth_decomp <- baci_bilateral %>%
  filter(year %in% c(2016, 2023)) %>%
  select(year, partner, total_trade) %>%
  pivot_wider(names_from = year, values_from = total_trade,
              names_prefix = "y") %>%
  mutate(
    abs_growth   = y2023 - y2016,
    pct_growth   = (y2023 - y2016) / y2016 * 100,
    share_growth = abs_growth / sum(abs_growth) * 100
  )

fig11 <- growth_decomp %>%
  pivot_longer(c(pct_growth, share_growth),
               names_to = "metric", values_to = "value") %>%
  mutate(
    metric = recode(metric,
                    pct_growth   = "% Growth 2016–2023",
                    share_growth = "Share of Total Growth Added (%)")
  ) %>%
  ggplot(aes(partner, value, fill = partner)) +
  geom_col(width = 0.6, alpha = 0.9) +
  geom_text(aes(label = round(value, 1)), vjust = -0.4, size = 3.5) +
  facet_wrap(~metric, scales = "free_y") +
  scale_fill_manual(values = c("China" = CLR_CHINA,
                               "Japan" = CLR_JAPAN,
                               "S. Korea" = CLR_KOREA),
                    guide = "none") +
  labs(
    title    = "Figure 11. Post-Reform Trade Growth Decomposition by Northeast Asian Partner",
    subtitle = "Comparing 2016 (pre-reform) to 2023 (latest available)",
    x        = NULL,
    y        = NULL,
    caption  = "Source: Author calculations from UN Comtrade bilateral trade data."
  ) +
  THEME_THESIS

save_fig(fig11, "fig11_growth_decomposition")

# =============================================================================
# Summary message
# =============================================================================
message("\n========================================")
message("All figures saved to: ", OUTPUT_DIR)
message("Figures generated:")
message("  fig7  — Bilateral trade flows UZB ↔ CN/JP/KR")
message("  fig8  — FDI inflows by Northeast Asian origin")
message("  fig9  — Intermediate goods share of imports")
message("  fig10 — Trade-Manufacturing-ECI mechanism scatter")
message("  fig11 — Post-reform trade growth decomposition")
message("\nNEXT STEPS:")
message("  1. Run fetch scripts to get actual data")
message("  2. For FDI, download from UNCTAD and run fetch_fdi_data.R")
message("  3. For intermediate goods, process HS data manually")
message("  4. Run this script: Rscript generate_figures.R")
message("  5. Feed the generated PDFs to your LaTeX document")
message("========================================\n")