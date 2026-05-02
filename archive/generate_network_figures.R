# =============================================================================
# generate_network_figures.R
# Produces Figures 12–16 for the Trade Network Analysis section
# Inputs:  data/processed/network_*.csv
# Outputs: figures/fig12_*.png … fig16_*.png
# Run: Rscript generate_network_figures.R
# =============================================================================

pkgs <- c("dplyr","tidyr","readr","ggplot2","ggraph","tidygraph","igraph",
          "patchwork","scales","ggrepel","viridis","forcats")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "http://cran.us.r-project.org")
  library(p, character.only = TRUE)
}))

PROC_DIR   <- "data/processed"
OUTPUT_DIR <- "figures"
dir.create(OUTPUT_DIR, showWarnings = FALSE)

REFORM_YEAR <- 2017
CLR <- list(
  china  = "#1a6b8a", japan = "#c0392b", korea = "#27ae60",
  uzb    = "#e67e22", row   = "#8e44ad", kaz   = "#16a085",
  rus    = "#2c3e50", reform= "#e67e22",
  intermediate = "#e67e22", commodity = "#2980b9",
  capital = "#c0392b", consumer = "#27ae60"
)

THEME <- theme_minimal(base_size = 12) +
  theme(
    plot.title      = element_text(face="bold", size=14),
    plot.subtitle   = element_text(color="grey35", size=10),
    plot.caption    = element_text(color="grey50", size=8, hjust=0),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    strip.text      = element_text(face="bold", size=11),
    plot.background = element_rect(fill="white", color=NA)
  )

save_png <- function(p, name, w=11, h=7) {
  path <- file.path(OUTPUT_DIR, paste0(name, ".png"))
  ggsave(path, plot=p, width=w, height=h, dpi=300, bg="white")
  message("Saved: ", path)
}

# ── Load processed data ─────────────────────────────────────────────────────────
nodes     <- read_csv(file.path(PROC_DIR, "network_nodes.csv"),        show_col_types=FALSE)
edges     <- read_csv(file.path(PROC_DIR, "network_edges.csv"),        show_col_types=FALSE)
dep       <- read_csv(file.path(PROC_DIR, "network_intermediate_dependence.csv"), show_col_types=FALSE)
exp_comp  <- read_csv(file.path(PROC_DIR, "network_export_composition.csv"),     show_col_types=FALSE)
metrics   <- read_csv(file.path(PROC_DIR, "network_node_metrics.csv"),           show_col_types=FALSE)

# ─────────────────────────────────────────────────────────────────────────────
# FIG 12 — Directed Trade Network Map (igraph / ggraph)
# ─────────────────────────────────────────────────────────────────────────────
message("Generating Fig 12: Trade network map...")

g <- tbl_graph(
  nodes = nodes %>% mutate(size_metric = ifelse(name=="UZB", 5, 3)),
  edges = edges %>%
    mutate(
      flow_color = case_when(
        flow_type == "Intermediate Import"   ~ "Intermediate Import",
        flow_type == "Primary Commodity Export" ~ "Commodity Export",
        flow_type == "Textile/Consumer Export"  ~ "Consumer Export",
        TRUE                                    ~ "Re-export Potential"
      )
    ),
  directed = TRUE
)

node_colors <- c("Hub/Target"="#e67e22","Source"="#1a6b8a","Re-export Market"="#27ae60","Commodity Market"="#8e44ad")
edge_colors <- c("Intermediate Import"="#e67e22","Commodity Export"="#2980b9","Consumer Export"="#27ae60","Re-export Potential"="#95a5a6")

fig12 <- ggraph(g, layout="stress") +
  geom_edge_arc(
    aes(width=log1p(weight_bn)*0.8, color=flow_color, alpha=intermediate_share),
    strength=0.2,
    arrow=arrow(length=unit(3,"mm"), type="closed"),
    end_cap=circle(7,"mm"), start_cap=circle(4,"mm")
  ) +
  scale_edge_color_manual(values=edge_colors, name="Flow Type") +
  scale_edge_width(range=c(0.5,4), guide="none") +
  scale_edge_alpha(range=c(0.4,0.95), guide="none") +
  geom_node_point(aes(color=role, size=size_metric)) +
  geom_node_text(aes(label=name), fontface="bold", size=4.5, repel=TRUE, box.padding=0.5) +
  scale_color_manual(values=node_colors, name="Node Role") +
  scale_size(range=c(6,14), guide="none") +
  labs(
    title    = "Figure 12. Uzbekistan's Trade Network: Value-Chain Positioning Map",
    subtitle = paste0("Directed flows: intermediate imports (NE Asia→UZB), commodity & re-export flows (UZB→partners), latest year"),
    caption  = "Source: OEC/BACI bilateral trade data. Edge width ∝ log(trade volume); opacity ∝ intermediate goods share.\nBEC Rev.5 classification: HS sections 05,06,07,15,16,17,18 classified as intermediate."
  ) +
  theme_graph(base_family="sans") +
  theme(
    plot.title    = element_text(face="bold", size=14),
    plot.subtitle = element_text(size=10, color="grey30"),
    plot.caption  = element_text(size=8, color="grey50"),
    legend.position = "bottom",
    legend.box = "horizontal",
    plot.background = element_rect(fill="white", color=NA),
    plot.margin = margin(10,10,10,10)
  )

save_png(fig12, "fig12_trade_network_map", w=12, h=8)

# ─────────────────────────────────────────────────────────────────────────────
# FIG 13 — Intermediate Goods Dependence: Time-Series by Partner
# ─────────────────────────────────────────────────────────────────────────────
message("Generating Fig 13: Intermediate goods dependence...")

if (nrow(dep) > 0) {
  p13a <- dep %>%
    filter(!is.na(intermediate_share)) %>%
    ggplot(aes(year, intermediate_share, color=partner_label, group=partner_label)) +
    geom_vline(xintercept=REFORM_YEAR, linetype="dashed", color=CLR$reform, linewidth=0.9) +
    geom_line(linewidth=1.2) +
    geom_point(size=2.5) +
    annotate("text", x=REFORM_YEAR+0.3, y=0.98, label="2017 Reform",
             color=CLR$reform, hjust=0, size=3.2, fontface="italic") +
    scale_color_manual(values=c("China"=CLR$china,"Japan"=CLR$japan,"S. Korea"=CLR$korea), name=NULL) +
    scale_y_continuous(labels=label_percent(), limits=c(0.3,1.05)) +
    labs(title="A. Intermediate Goods Share of Imports from NE Asia",
         x=NULL, y="Share (%)") + THEME

  p13b <- dep %>%
    filter(!is.na(intermediate_usd)) %>%
    ggplot(aes(year, intermediate_usd/1e9, color=partner_label, group=partner_label)) +
    geom_vline(xintercept=REFORM_YEAR, linetype="dashed", color=CLR$reform, linewidth=0.9) +
    geom_area(aes(fill=partner_label), alpha=0.15, position="identity") +
    geom_line(linewidth=1.1) +
    scale_color_manual(values=c("China"=CLR$china,"Japan"=CLR$japan,"S. Korea"=CLR$korea), name=NULL) +
    scale_fill_manual(values=c("China"=CLR$china,"Japan"=CLR$japan,"S. Korea"=CLR$korea), guide="none") +
    scale_y_continuous(labels=label_dollar(suffix="B")) +
    labs(title="B. Total Intermediate Goods Imported (USD Bn)",
         x="Year", y="USD Billion") + THEME

  fig13 <- (p13a / p13b) +
    plot_annotation(
      title   = "Figure 13. Intermediate Goods Dependence: Uzbekistan's Imports from NE Asia (2010–2023)",
      subtitle= "Panel A: share; Panel B: absolute volume. Higher share = deeper potential GVC embedding.",
      caption = "Source: OEC/BACI HS-section bilateral trade data. BEC Rev.5 intermediate goods: HS sections 05,06,07,15,16,17,18.",
      theme   = theme(plot.title=element_text(face="bold", size=13))
    )
  save_png(fig13, "fig13_intermediate_dependence", w=11, h=8)
}

# ─────────────────────────────────────────────────────────────────────────────
# FIG 14 — Uzbekistan Export Composition: Structural Change 2010–2023
# ─────────────────────────────────────────────────────────────────────────────
message("Generating Fig 14: Export composition...")

if (nrow(exp_comp) > 0) {
  # Stacked bar by year, showing structural change
  exp_agg <- exp_comp %>%
    filter(!is.na(good_type)) %>%
    group_by(year, good_type) %>%
    summarise(export_usd = sum(export_usd, na.rm=TRUE), .groups="drop") %>%
    group_by(year) %>%
    mutate(share = export_usd / sum(export_usd)) %>%
    ungroup() %>%
    mutate(good_type = fct_reorder(good_type, -share, .fun=mean))

  type_colors <- c(
    "Gold/Precious Metals" = "#f39c12",
    "Textiles"             = "#3498db",
    "Other Primary"        = "#95a5a6",
    "Intermediate Input"   = "#e67e22",
    "Capital/Machines"     = "#c0392b",
    "Consumer/Other"       = "#27ae60"
  )

  p14a <- exp_agg %>%
    ggplot(aes(year, share, fill=good_type)) +
    geom_col(width=0.85, position="stack") +
    geom_vline(xintercept=REFORM_YEAR-0.5, linetype="dashed", color="white", linewidth=1) +
    annotate("text", x=REFORM_YEAR+0.1, y=0.95, label="2017", color="grey30", size=3, hjust=0) +
    scale_fill_manual(values=type_colors, name="Export Category") +
    scale_y_continuous(labels=label_percent()) +
    labs(title="A. Export Composition by Category (% share)", x=NULL, y=NULL) +
    THEME + theme(legend.position="right")

  p14b <- exp_agg %>%
    ggplot(aes(year, export_usd/1e9, fill=good_type)) +
    geom_col(width=0.85, position="stack") +
    geom_vline(xintercept=REFORM_YEAR-0.5, linetype="dashed", color="grey30", linewidth=0.8) +
    scale_fill_manual(values=type_colors, name="Export Category") +
    scale_y_continuous(labels=label_dollar(suffix="B")) +
    labs(title="B. Export Volume by Category (USD Bn)", x="Year", y="USD Billion") +
    THEME + theme(legend.position="right")

  fig14 <- (p14a / p14b) +
    plot_annotation(
      title   = "Figure 14. Uzbekistan Export Composition: Structural Change 2010–2023",
      subtitle= "Persistent dominance of Gold/Precious Metals; manufactured goods share growing but still marginal.",
      caption = "Source: OEC/BACI HS-section export data. Gold classified under HS section 14 (Precious Metals).",
      theme   = theme(plot.title=element_text(face="bold",size=13))
    )
  save_png(fig14, "fig14_export_composition", w=12, h=9)
}

# ─────────────────────────────────────────────────────────────────────────────
# FIG 15 — Re-export Potential: Manufactured Goods in UZB Exports to CA Markets
# ─────────────────────────────────────────────────────────────────────────────
message("Generating Fig 15: Re-export potential heatmap...")

# Computed from edges: what manufactured goods flow UZB → CA/Eurasia
reexport_edges <- edges %>%
  filter(from=="UZB", to %in% c("KAZ","RUS","TUR","ROW"),
         flow_type %in% c("Re-export Potential","Textile/Consumer Export","Mixed Exports")) %>%
  mutate(to_label = case_when(
    to=="KAZ"~"Kazakhstan",to=="RUS"~"Russia",to=="TUR"~"Turkey",TRUE~"Rest of World"
  ))

if (nrow(reexport_edges) > 0) {
  fig15 <- reexport_edges %>%
    ggplot(aes(x=to_label, y=flow_type, fill=weight_bn)) +
    geom_tile(color="white", linewidth=0.5) +
    geom_text(aes(label=paste0("$",round(weight_bn,2),"B")), size=3.5, fontface="bold") +
    scale_fill_gradient(low="#fef9e7", high="#e67e22", name="Trade Flow (USD Bn)") +
    labs(
      title   = "Figure 15. Re-export Potential: Uzbekistan's Manufactured Goods Exports to Eurasia",
      subtitle= "Flows of intermediate and consumer goods from UZB to Central Asian and Eurasian markets (latest year)",
      x=NULL, y="Flow Type",
      caption = "Source: OEC/BACI bilateral trade, latest available year. Re-export potential = intermediate + capital goods flowing outward."
    ) +
    THEME + theme(panel.grid=element_blank())
  save_png(fig15, "fig15_reexport_potential", w=10, h=5)
}

# ─────────────────────────────────────────────────────────────────────────────
# FIG 16 — GVC Positioning: Backward vs Forward Integration
#           Scatter: Intermediate Import Share (backward) vs
#                    Manufactured Export Share (forward)
# ─────────────────────────────────────────────────────────────────────────────
message("Generating Fig 16: GVC positioning scatter...")

gvc_file <- file.path(PROC_DIR, "network_gvc_index.csv")
if (file.exists(gvc_file)) {
  gvc <- read_csv(gvc_file, show_col_types=FALSE)

  # Forward proxy: manufactured exports share from export composition
  fwd_proxy <- exp_comp %>%
    group_by(year) %>%
    summarise(
      total = sum(export_usd, na.rm=TRUE),
      manuf = sum(export_usd[good_type %in% c("Capital/Machines","Intermediate Input","Textiles")], na.rm=TRUE),
      forward_proxy = manuf / pmax(total, 1),
      .groups="drop"
    )

  gvc_full <- left_join(gvc, fwd_proxy, by="year") %>%
    mutate(
      phase = case_when(
        year < REFORM_YEAR ~ "Pre-Reform (2010–2016)",
        year < 2021        ~ "Early Reform (2017–2020)",
        TRUE               ~ "Post-COVID (2021–2023)"
      )
    )

  if (nrow(gvc_full) > 2) {
    fig16 <- gvc_full %>%
      ggplot(aes(backward_gvc_proxy, forward_proxy, color=phase)) +
      geom_path(aes(group=1), color="grey70", linewidth=0.8, linetype="dashed") +
      geom_point(size=4, alpha=0.9) +
      geom_text_repel(aes(label=year), size=3, box.padding=0.4) +
      annotate("segment", x=0.5, xend=0.9, y=0.25, yend=0.25,
               arrow=arrow(length=unit(3,"mm")), color="grey40") +
      annotate("text", x=0.7, y=0.24, label="↑ Backward integration (more import dependence)", size=3, color="grey40") +
      annotate("segment", x=0.5, xend=0.5, y=0.05, yend=0.35,
               arrow=arrow(length=unit(3,"mm")), color="grey40") +
      annotate("text", x=0.51, y=0.2, label="↑ Forward integration\n(more mfg exports)", size=3, color="grey40", hjust=0) +
      scale_color_manual(values=c("Pre-Reform (2010–2016)"="#95a5a6",
                                  "Early Reform (2017–2020)"="#e67e22",
                                  "Post-COVID (2021–2023)"="#1a6b8a"), name=NULL) +
      scale_x_continuous(labels=label_percent(), name="Backward GVC Proxy (Intermediate Import Share)") +
      scale_y_continuous(labels=label_percent(), name="Forward GVC Proxy (Manufactured Export Share)") +
      labs(
        title   = "Figure 16. GVC Positioning: Uzbekistan's Backward vs. Forward Integration (2010–2023)",
        subtitle= "Ideal trajectory: move toward upper-right quadrant (high backward + forward integration).",
        caption = "Source: Author calculations from OEC/BACI data. Backward proxy = share of intermediate goods in total imports from NE Asia.\nForward proxy = share of manufactured + intermediate exports in total exports."
      ) +
      THEME
    save_png(fig16, "fig16_gvc_positioning", w=11, h=7)
  }
}

# ─────────────────────────────────────────────────────────────────────────────
message("\n========================================")
message("ALL NETWORK FIGURES GENERATED")
message("Figures saved to: ", OUTPUT_DIR)
message(paste("  fig12 — Trade network directed map"))
message(paste("  fig13 — Intermediate goods dependence (2 panels)"))
message(paste("  fig14 — Export composition structural change (2 panels)"))
message(paste("  fig15 — Re-export potential heatmap"))
message(paste("  fig16 — GVC positioning scatter (backward vs forward)"))
message("Next step: Compile report_main.tex (pdflatex)")
message("========================================\n")
