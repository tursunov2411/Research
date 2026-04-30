# ============================================================
# THESIS: FDI-Led Industrialisation and GVC Embedding in
#         Uzbekistan
# Author: [Your Name]
# Supervisor: [Supervisor Name]
# Institution: Toshkent Davlat Iqtisodiyot Universiteti
# Date: 2026
# Script: 00_setup.R — Package installation and configuration
# ============================================================

# Research Ethics Declaration
# All data used in this analysis is sourced from publicly
# available institutional databases (World Bank, UNCTAD,
# UN Comtrade, Uzbekistan State Statistics Committee).
# No personally identifiable information is used.
# All code is version-controlled via Git for full
# reproducibility. Raw data files are preserved unmodified.

# Install required packages (run once)
packages_required <- c(
  "tidyverse",    # Data manipulation and visualisation
  "readxl",       # Read Excel files
  "haven",        # Read Stata files
  "writexl",      # Export to Excel
  "ggplot2",      # Publication-quality graphs
  "scales",       # Scale formatting for graphs
  "strucchange",  # Structural break / Chow test
  "lmtest",       # Linear model tests
  "sandwich",     # Robust standard errors
  "stargazer",    # Regression output tables
  "knitr",        # R Markdown output
  "kableExtra",   # Table formatting
  "WDI",          # World Bank API direct access
  "countrycode",  # Country code standardisation
  "zoo",          # Time series handling
  "forecast",     # Time series analysis
  "broom",        # Tidy model outputs
  "patchwork",    # Combine ggplot figures
  "RColorBrewer", # Colour palettes
  "ggthemes"      # Academic graph themes
)

options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install missing packages
new_packages <- packages_required[
  !(packages_required %in% installed.packages()[, "Package"])
]
if (length(new_packages)) install.packages(new_packages)

# Load all packages
lapply(packages_required, library, character.only = TRUE)

# Set global options
options(scipen = 999)         # Disable scientific notation
options(digits = 4)           # 4 decimal places
Sys.setlocale("LC_TIME", "C") # Consistent date handling

# Define colour palette (consistent across all figures)
thesis_colours <- c(
  "uzbekistan" = "#1B4F72",   # Dark blue
  "vietnam"    = "#C0392B",   # Red
  "highlight"  = "#F39C12",   # Amber
  "neutral"    = "#7F8C8D",   # Grey
  "positive"   = "#27AE60",   # Green
  "negative"   = "#E74C3C"    # Red
)

# Define ggplot theme for all figures
theme_thesis <- theme_minimal() +
  theme(
    text = element_text(family = "serif", size = 11),
    plot.title = element_text(size = 13, face = "bold",
                              hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5,
                                 color = "grey40"),
    axis.title = element_text(size = 10, face = "bold"),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.caption = element_text(size = 8, color = "grey50",
                                hjust = 0),
    plot.background = element_rect(fill = "white",
                                   color = NA)
  )

# Save theme as default
theme_set(theme_thesis)

cat("Setup complete. All packages loaded.\n")
cat("Project:", getwd(), "\n")
cat("R version:", R.version$version.string, "\n")
