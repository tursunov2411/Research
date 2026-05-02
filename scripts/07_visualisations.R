# ============================================================
# Script: 07_visualisations.R
# Purpose: Consolidated figure generation for the dissertation.
#          Migrates all figure production from root-level
#          generate_figures.R and generate_network_figures.R
#          into the numbered script pipeline.
# Outputs: output/figures/*.png (all dissertation figures)
# ============================================================

source("scripts/00_setup.R")

# Additional packages for network figures
network_pkgs <- c("ggraph", "tidygraph", "igraph", "viridis", "forcats")
invisible(lapply(network_pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
  library(p, character.only = TRUE)
}))

library(ggrepel)
library(readr)

# -------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------

# Primary output: figures/ (where report_main.tex \includegraphics expects them)
# Also copy to output/figures/ for the numbered-pipeline convention
OUTPUT_DIR <- "figures"
OUTPUT_DIR_ALT <- "output/figures"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUTPUT_DIR_ALT, recursive = TRUE, showWarnings = FALSE)

REFORM_YEAR <- 2017

# Colour palette (unified across all figures)
CLR <- list(
  china  = "#1a6b8a", japan = "#c0392b", korea = "#27ae60",
  uzb    = "#e67e22", row   = "#8e44ad", kaz   = "#16a085",
  rus    = "#2c3e50", reform= "#e67e22",
  intermediate = "#e67e22", commodity = "#2980b9",
  capital = "#c0392b", consumer = "#27ae60"
)

THEME_FIG <- theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(color = "grey40", size = 10),
    plot.caption     = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    strip.text       = element_text(face = "bold"),
    plot.background  = element_rect(fill = "white", color = NA)
  )

save_fig <- function(p, name, w = 10, h = 6) {
  # Save to primary directory (for LaTeX)
  path_png <- file.path(OUTPUT_DIR, paste0(name, ".png"))
  ggsave(path_png, plot = p, width = w, height = h, dpi = 300, bg = "white")
  # Copy to alternate directory (for pipeline consistency)
  path_alt <- file.path(OUTPUT_DIR_ALT, paste0(name, ".png"))
  file.copy(path_png, path_alt, overwrite = TRUE)
  message("Saved: ", path_png, " (+ ", path_alt, ")")
}

# =============================================================================
# PART A: BILATERAL TRADE & FDI FIGURES (from generate_figures.R)
# =============================================================================

# --- Fig 7: Bilateral Trade Flows ---
baci_file <- "data/baci_bilateral_trade.csv"
if (file.exists(baci_file)) {
  message("Generating Fig 7: Bilateral trade flows...")

  baci_bilateral <- read_csv(baci_file, show_col_types = FALSE) %>%
    mutate(
      trade_balance   = exports_mn_usd - imports_mn_usd,
      total_trade     = exports_mn_usd + imports_mn_usd,
      post_reform     = year >= REFORM_YEAR
    )

  p7a <- baci_bilateral %>%
    ggplot(aes(year, total_trade / 1000, colour = partner, group = partner)) +
    geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
               colour = CLR$reform, linewidth = 0.8) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    annotate("text", x = REFORM_YEAR + 0.3, y = 5.5,
             label = "2017 Reform", colour = CLR$reform,
             hjust = 0, size = 3.2) +
    scale_colour_manual(values = c("China" = CLR$china,
                                   "Japan" = CLR$japan,
                                   "S. Korea" = CLR$korea)) +
    scale_y_continuous(labels = label_dollar(suffix = "B")) +
    labs(title = "A. Total Trade (Exports + Imports)",
         x = NULL, y = "USD Billion", colour = NULL) +
    THEME_FIG

  p7b <- baci_bilateral %>%
    ggplot(aes(year, trade_balance / 1000, colour = partner, group = partner)) +
    geom_hline(yintercept = 0, linetype = "solid", colour = "grey60") +
    geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
               colour = CLR$reform, linewidth = 0.8) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    scale_colour_manual(values = c("China" = CLR$china,
                                   "Japan" = CLR$japan,
                                   "S. Korea" = CLR$korea)) +
    scale_y_continuous(labels = label_dollar(suffix = "B")) +
    labs(title = "B. Trade Balance (Exports minus Imports)",
         x = "Year", y = "USD Billion", colour = NULL) +
    THEME_FIG

  fig7 <- (p7a / p7b) +
    plot_annotation(
      title    = "Uzbekistan Bilateral Trade with Northeast Asia Triad (2010–2023)",
      subtitle = "China, Japan, and South Korea; vertical dashed line marks 2017 liberalisation reform",
      caption  = "Source: Author calculations based on UN Comtrade data.",
      theme    = theme(plot.title = element_text(face = "bold", size = 13))
    )
  save_fig(fig7, "fig7_bilateral_trade")

  # --- Fig 11: Growth Decomposition ---
  message("Generating Fig 11: Growth decomposition...")
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
    mutate(metric = recode(metric,
                           pct_growth   = "% Growth 2016–2023",
                           share_growth = "Share of Total Growth Added (%)")) %>%
    ggplot(aes(partner, value, fill = partner)) +
    geom_col(width = 0.6, alpha = 0.9) +
    geom_text(aes(label = round(value, 1)), vjust = -0.4, size = 3.5) +
    facet_wrap(~metric, scales = "free_y") +
    scale_fill_manual(values = c("China" = CLR$china,
                                 "Japan" = CLR$japan,
                                 "S. Korea" = CLR$korea), guide = "none") +
    labs(title = "Post-Reform Trade Growth Decomposition",
         subtitle = "Comparing 2016 (pre-reform) to 2023 (latest available)",
         x = NULL, y = NULL,
         caption = "Source: Author calculations from UN Comtrade bilateral trade data.") +
    THEME_FIG
  save_fig(fig11, "fig11_growth_decomposition")
} else {
  message("Skipping Fig 7 & 11: ", baci_file, " not found.")
}

# --- Fig 8: FDI by Origin ---
fdi_file <- "data/fdi_bilateral_processed.csv"
if (file.exists(fdi_file)) {
  message("Generating Fig 8: FDI by origin...")
  fdi_bilateral <- read_csv(fdi_file, show_col_types = FALSE)

  fig8 <- fdi_bilateral %>%
    ggplot(aes(year, fdi_mn_usd, fill = origin)) +
    geom_col(position = "stack", width = 0.7, alpha = 0.9) +
    geom_vline(xintercept = REFORM_YEAR - 0.5, linetype = "dashed",
               colour = CLR$reform, linewidth = 0.9) +
    scale_fill_manual(values = c("China" = CLR$china,
                                 "Japan" = CLR$japan,
                                 "S. Korea" = CLR$korea)) +
    scale_y_continuous(labels = label_dollar(suffix = "M")) +
    scale_x_continuous(breaks = 2015:2023) +
    labs(title = "FDI Inflows into Uzbekistan by Northeast Asian Origin",
         subtitle = "Annual FDI flows from China, Japan, and South Korea; USD million",
         x = "Year", y = "FDI Inflow (USD Million)", fill = NULL,
         caption = "Source: UNCTAD bilateral FDI statistics.") +
    THEME_FIG
  save_fig(fig8, "fig8_fdi_by_origin")
} else {
  message("Skipping Fig 8: ", fdi_file, " not found.")
}

# --- Fig 10: Mechanism Trajectory ---
macro_file <- "data/macro_data.csv"
if (file.exists(macro_file)) {
  message("Generating Fig 10: Mechanism trajectory...")
  macro_data <- read_csv(macro_file, show_col_types = FALSE)

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
      midpoint = -0.35, name = "ECI Score"
    ) +
    scale_size_continuous(range = c(3, 8), guide = "none") +
    labs(title = "Trade Openness, Manufacturing VA, and ECI Trajectory",
         subtitle = "Dot size and colour reflect ECI level; path traces time",
         x = "Trade Openness Index (2010 = 100)",
         y = "Manufacturing VA (% of GDP)",
         caption = "Source: World Bank WDI and OEC.") +
    THEME_FIG + theme(legend.position = "right")
  save_fig(fig10, "fig10_mechanism_trajectory")
} else {
  message("Skipping Fig 10: ", macro_file, " not found.")
}

# =============================================================================
# PART B: NETWORK FIGURES (from generate_network_figures.R)
# =============================================================================

PROC_DIR <- "data/processed"

# Check if network data exists
network_files_exist <- all(file.exists(
  file.path(PROC_DIR, "network_nodes.csv"),
  file.path(PROC_DIR, "network_edges.csv")
))

if (network_files_exist) {
  message("\n=== Generating Network Figures ===")

  nodes     <- read_csv(file.path(PROC_DIR, "network_nodes.csv"), show_col_types = FALSE)
  edges     <- read_csv(file.path(PROC_DIR, "network_edges.csv"), show_col_types = FALSE)

  # --- Fig 12: Trade Network Map ---
  message("Generating Fig 12: Trade network map...")
  g <- tbl_graph(
    nodes = nodes %>% mutate(size_metric = ifelse(name == "UZB", 5, 3)),
    edges = edges %>%
      mutate(flow_color = case_when(
        flow_type == "Intermediate Import"     ~ "Intermediate Import",
        flow_type == "Primary Commodity Export" ~ "Commodity Export",
        flow_type == "Textile/Consumer Export"  ~ "Consumer Export",
        TRUE                                   ~ "Re-export Potential"
      )),
    directed = TRUE
  )

  node_colors <- c("Hub/Target" = "#e67e22", "Source" = "#1a6b8a",
                    "Re-export Market" = "#27ae60", "Commodity Market" = "#8e44ad")
  edge_colors <- c("Intermediate Import" = "#e67e22", "Commodity Export" = "#2980b9",
                    "Consumer Export" = "#27ae60", "Re-export Potential" = "#95a5a6")

  fig12 <- ggraph(g, layout = "stress") +
    geom_edge_arc(
      aes(width = log1p(weight_bn) * 0.8, color = flow_color,
          alpha = intermediate_share),
      strength = 0.2,
      arrow = arrow(length = unit(3, "mm"), type = "closed"),
      end_cap = circle(7, "mm"), start_cap = circle(4, "mm")
    ) +
    scale_edge_color_manual(values = edge_colors, name = "Flow Type") +
    scale_edge_width(range = c(0.5, 4), guide = "none") +
    scale_edge_alpha(range = c(0.4, 0.95), guide = "none") +
    geom_node_point(aes(color = role, size = size_metric)) +
    geom_node_text(aes(label = name), fontface = "bold", size = 4.5,
                   repel = TRUE, box.padding = 0.5) +
    scale_color_manual(values = node_colors, name = "Node Role") +
    scale_size(range = c(6, 14), guide = "none") +
    labs(
      title    = "Uzbekistan's Trade Network: Value-Chain Positioning Map",
      subtitle = "Directed flows: intermediate imports (NE Asia→UZB), commodity & re-export flows",
      caption  = "Source: OEC/BACI bilateral trade data. Edge width ∝ log(trade volume)."
    ) +
    theme_graph(base_family = "sans") +
    theme(
      plot.title      = element_text(face = "bold", size = 14),
      plot.subtitle   = element_text(size = 10, color = "grey30"),
      plot.caption    = element_text(size = 8, color = "grey50"),
      legend.position = "bottom",
      plot.background = element_rect(fill = "white", color = NA)
    )
  save_fig(fig12, "fig12_trade_network_map", w = 12, h = 8)

  # --- Fig 13: Intermediate Goods Dependence ---
  dep_file <- "output/tables/table_intermediate_goods_share.csv"
  if (file.exists(dep_file)) {
    message("Generating Fig 13: Intermediate goods dependence...")
    dep <- read_csv(dep_file, show_col_types = FALSE) %>%
      mutate(
        partner_label = partner,
        intermediate_share = share_intermediate,
        intermediate_usd = intermediate_imports_usd
      )

    if (nrow(dep) > 0) {
      p13a <- dep %>%
        filter(!is.na(intermediate_share)) %>%
        ggplot(aes(year, intermediate_share, color = partner_label,
                   group = partner_label)) +
        geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
                   color = CLR$reform, linewidth = 0.9) +
        geom_line(linewidth = 1.2) +
        geom_point(size = 2.5) +
        scale_color_manual(values = c("China" = CLR$china,
                                      "Japan" = CLR$japan,
                                      "South Korea" = CLR$korea), name = NULL) +
        scale_y_continuous(labels = label_percent(), limits = c(0.3, 1.05)) +
        labs(title = "A. Intermediate Goods Share of Imports from NE Asia",
             x = NULL, y = "Share (%)") + THEME_FIG

      p13b <- dep %>%
        filter(!is.na(intermediate_usd)) %>%
        ggplot(aes(year, intermediate_usd / 1e9, color = partner_label,
                   group = partner_label)) +
        geom_vline(xintercept = REFORM_YEAR, linetype = "dashed",
                   color = CLR$reform, linewidth = 0.9) +
        geom_area(aes(fill = partner_label), alpha = 0.15, position = "identity") +
        geom_line(linewidth = 1.1) +
        scale_color_manual(values = c("China" = CLR$china,
                                      "Japan" = CLR$japan,
                                      "South Korea" = CLR$korea), name = NULL) +
        scale_fill_manual(values = c("China" = CLR$china,
                                     "Japan" = CLR$japan,
                                     "South Korea" = CLR$korea), guide = "none") +
        scale_y_continuous(labels = label_dollar(suffix = "B")) +
        labs(title = "B. Total Intermediate Goods Imported (USD Bn)",
             x = "Year", y = "USD Billion") + THEME_FIG

      fig13 <- (p13a / p13b) +
        plot_annotation(
          title    = "Intermediate Goods Dependence: UZB Imports from NE Asia",
          subtitle = "Panel A: share; Panel B: absolute volume",
          caption  = "Source: OEC/BACI HS-section bilateral trade data.",
          theme    = theme(plot.title = element_text(face = "bold", size = 13))
        )
      save_fig(fig13, "fig13_intermediate_dependence", w = 11, h = 8)
    }
  }

  # --- Fig 14: Export Composition ---
  exp_file <- file.path(PROC_DIR, "network_export_composition.csv")
  if (file.exists(exp_file)) {
    message("Generating Fig 14: Export composition...")
    exp_comp <- read_csv(exp_file, show_col_types = FALSE)

    if (nrow(exp_comp) > 0) {
      exp_agg <- exp_comp %>%
        filter(!is.na(good_type)) %>%
        group_by(year, good_type) %>%
        summarise(export_usd = sum(export_usd, na.rm = TRUE), .groups = "drop") %>%
        group_by(year) %>%
        mutate(share = export_usd / sum(export_usd)) %>%
        ungroup() %>%
        mutate(good_type = fct_reorder(good_type, -share, .fun = mean))

      type_colors <- c(
        "Gold/Precious Metals" = "#f39c12", "Textiles" = "#3498db",
        "Other Primary" = "#95a5a6", "Intermediate Input" = "#e67e22",
        "Capital/Machines" = "#c0392b", "Consumer/Other" = "#27ae60"
      )

      p14a <- exp_agg %>%
        ggplot(aes(year, share, fill = good_type)) +
        geom_col(width = 0.85, position = "stack") +
        geom_vline(xintercept = REFORM_YEAR - 0.5, linetype = "dashed",
                   color = "white", linewidth = 1) +
        scale_fill_manual(values = type_colors, name = "Export Category") +
        scale_y_continuous(labels = label_percent()) +
        labs(title = "A. Export Composition by Category (% share)",
             x = NULL, y = NULL) +
        THEME_FIG + theme(legend.position = "right")

      p14b <- exp_agg %>%
        ggplot(aes(year, export_usd / 1e9, fill = good_type)) +
        geom_col(width = 0.85, position = "stack") +
        geom_vline(xintercept = REFORM_YEAR - 0.5, linetype = "dashed",
                   color = "grey30", linewidth = 0.8) +
        scale_fill_manual(values = type_colors, name = "Export Category") +
        scale_y_continuous(labels = label_dollar(suffix = "B")) +
        labs(title = "B. Export Volume by Category (USD Bn)",
             x = "Year", y = "USD Billion") +
        THEME_FIG + theme(legend.position = "right")

      fig14 <- (p14a / p14b) +
        plot_annotation(
          title    = "Uzbekistan Export Composition: 2010–2023",
          subtitle = "Persistent dominance of Gold/Precious Metals",
          caption  = "Source: OEC/BACI HS-section export data.",
          theme    = theme(plot.title = element_text(face = "bold", size = 13))
        )
      save_fig(fig14, "fig14_export_composition", w = 12, h = 9)
    }
  }

  # --- Fig 15: Re-export Potential ---
  reexport_edges <- edges %>%
    filter(from == "UZB", to %in% c("KAZ", "RUS", "TUR", "ROW"),
           flow_type %in% c("Re-export Potential", "Textile/Consumer Export",
                            "Mixed Exports")) %>%
    mutate(to_label = case_when(
      to == "KAZ" ~ "Kazakhstan", to == "RUS" ~ "Russia",
      to == "TUR" ~ "Turkey", TRUE ~ "Rest of World"
    ))

  if (nrow(reexport_edges) > 0) {
    message("Generating Fig 15: Re-export potential...")
    fig15 <- reexport_edges %>%
      ggplot(aes(x = to_label, y = flow_type, fill = weight_bn)) +
      geom_tile(color = "white", linewidth = 0.5) +
      geom_text(aes(label = paste0("$", round(weight_bn, 2), "B")),
                size = 3.5, fontface = "bold") +
      scale_fill_gradient(low = "#fef9e7", high = "#e67e22",
                          name = "Trade Flow (USD Bn)") +
      labs(title = "Re-export Potential: UZB Manufactured Goods to Eurasia",
           x = NULL, y = "Flow Type",
           caption = "Source: OEC/BACI bilateral trade data.") +
      THEME_FIG + theme(panel.grid = element_blank())
    save_fig(fig15, "fig15_reexport_potential", w = 10, h = 5)
  }

  # --- Fig 16: GVC Positioning Scatter ---
  gvc_file <- file.path(PROC_DIR, "network_gvc_index.csv")
  if (file.exists(gvc_file) && file.exists(exp_file)) {
    message("Generating Fig 16: GVC positioning scatter...")
    gvc <- read_csv(gvc_file, show_col_types = FALSE)
    exp_comp <- read_csv(exp_file, show_col_types = FALSE)

    fwd_proxy <- exp_comp %>%
      group_by(year) %>%
      summarise(
        total = sum(export_usd, na.rm = TRUE),
        manuf = sum(export_usd[good_type %in% c("Capital/Machines",
                    "Intermediate Input", "Textiles")], na.rm = TRUE),
        forward_proxy = manuf / pmax(total, 1),
        .groups = "drop"
      )

    gvc_full <- left_join(gvc, fwd_proxy, by = "year") %>%
      mutate(phase = case_when(
        year < REFORM_YEAR ~ "Pre-Reform (2010–2016)",
        year < 2021        ~ "Early Reform (2017–2020)",
        TRUE               ~ "Post-COVID (2021–2023)"
      ))

    if (nrow(gvc_full) > 2) {
      fig16 <- gvc_full %>%
        ggplot(aes(backward_gvc_proxy, forward_proxy, color = phase)) +
        geom_path(aes(group = 1), color = "grey70", linewidth = 0.8,
                  linetype = "dashed") +
        geom_point(size = 4, alpha = 0.9) +
        geom_text_repel(aes(label = year), size = 3, box.padding = 0.4) +
        scale_color_manual(values = c(
          "Pre-Reform (2010–2016)" = "#95a5a6",
          "Early Reform (2017–2020)" = "#e67e22",
          "Post-COVID (2021–2023)" = "#1a6b8a"
        ), name = NULL) +
        scale_x_continuous(labels = label_percent(),
                           name = "Backward GVC Proxy (Intermediate Import Share)") +
        scale_y_continuous(labels = label_percent(),
                           name = "Forward GVC Proxy (Manufactured Export Share)") +
        labs(
          title   = "GVC Positioning: Backward vs. Forward Integration",
          subtitle = "Ideal trajectory: move toward upper-right quadrant",
          caption = "Source: Author calculations from OEC/BACI data."
        ) + THEME_FIG
      save_fig(fig16, "fig16_gvc_positioning", w = 11, h = 7)
    }
  }
} else {
  message("Network data not found in ", PROC_DIR, "; skipping Figs 12–16.")
}

# =============================================================================
# SUMMARY
# =============================================================================
message("\n========================================")
message("ALL VISUALISATIONS COMPLETE")
message("Figures saved to: ", OUTPUT_DIR)
message("  fig7  — Bilateral trade flows")
message("  fig8  — FDI inflows by NE Asian origin")
message("  fig10 — Trade-Manufacturing-ECI mechanism")
message("  fig11 — Post-reform trade growth decomposition")
message("  fig12 — Trade network directed map")
message("  fig13 — Intermediate goods dependence")
message("  fig14 — Export composition structural change")
message("  fig15 — Re-export potential heatmap")
message("  fig16 — GVC positioning scatter")
message("========================================\n")
