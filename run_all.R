# ============================================================
# MASTER SCRIPT: run_all.R
# Executes the complete Quarto statistical workflow
# Run this to fully reproduce all results
# ============================================================

cat("========================================\n")
cat("THESIS ANALYSIS - QUARTO PIPELINE\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

# ── Helper: timed stage runner ───────────────────────────────────────────────
run_stage <- function(label, script) {
  cat(sprintf("\n[STAGE] %s\n", label))
  cat(rep("-", 50), "\n", sep="")
  t0 <- proc.time()
  tryCatch(
    source(script, echo = FALSE),
    error = function(e) {
      cat(sprintf("  ERROR in %s: %s\n", script, e$message))
      cat("  Continuing with remaining pipeline stages...\n")
    }
  )
  elapsed <- (proc.time() - t0)[["elapsed"]]
  cat(sprintf("  Done in %.1fs\n", elapsed))
}


if (!file.exists("analysis.qmd") && file.exists("uzbekistan_thesis/analysis.qmd")) {
  setwd("uzbekistan_thesis")
}

find_quarto <- function() {
  quarto_path <- Sys.which("quarto")
  if (nzchar(quarto_path)) {
    return(unname(quarto_path))
  }

  candidates <- c(
    "C:/Program Files/Quarto/bin/quarto.exe",
    "C:/Program Files (x86)/Quarto/bin/quarto.exe"
  )
  candidates <- candidates[file.exists(candidates)]

  if (length(candidates) > 0) {
    return(candidates[[1]])
  }

  ""
}

quarto_path <- find_quarto()

if (!nzchar(quarto_path)) {
  stop(
    "Quarto CLI was not found. Install Quarto or render analysis.qmd from RStudio."
  )
}

cat("Rendering Quarto report with:", quarto_path, "\n\n")

render_output <- system2(
  quarto_path,
  "render",
  stdout = TRUE,
  stderr = TRUE
)

cat(paste(render_output, collapse = "\n"), "\n\n")

status <- attr(render_output, "status")
if (is.null(status)) {
  status <- 0L
}

if (!identical(status, 0L)) {
  stop("Quarto render failed with exit status ", status)
}

if (file.exists("scripts/09_scenario_forecasting.R")) {
  cat("Running scenario forecasting script...\n")
  source("scripts/09_scenario_forecasting.R")
  cat("\n")
}

cat("Exporting LaTeX table inputs...\n")
source("scripts/08_export_latex_tables.R")

# ── STAGE 3b: New chapter tables ──────────────────────────────────────────────
cat("\nExporting new chapter LaTeX tables...\n")
if (file.exists("scripts/15_export_new_chapter_tables.R")) {
  run_stage("3b. New chapter tables (benchmark, WGI, SEZ, constraints)",
            "scripts/15_export_new_chapter_tables.R")
}

# ── STAGE 4: Trade Network Analysis (fetch → process → figures) ──────────────
cat("\n========================================\n")
cat("[STAGE 4] Trade Network Analysis Pipeline\n")
cat("========================================\n")

# Set to FALSE to skip live API fetch (use cached data if already pulled)
FETCH_LIVE_DATA <- TRUE

if (FETCH_LIVE_DATA) {
  run_stage("4a. Fetch bilateral trade data (OEC, WB, OECD TiVA)", "fetch_network_data.R")
} else {
  cat("  [SKIP] fetch_network_data.R — using cached CSVs in data/raw/\n")
}

run_stage("4b. Process + classify (BEC intermediate goods, GVC index, edge list)", "process_network_data.R")
run_stage("4c. Generate network figures (Fig 12–16)", "generate_network_figures.R")

# ── STAGE 5: New Advanced Figures (Fig 17–21) ──────────────────────────────────
cat("\n========================================\n")
cat("[STAGE 5] New Advanced Figures (fig17–fig21)\n")
cat("========================================\n")
run_stage("5a. Thailand benchmark, WGI, institutional radar, SEZ scorecard, constraint matrix",
          "scripts/14_new_advanced_figures.R")

latex_engines <- Sys.which(c("latexmk", "lualatex", "pdflatex"))
latex_available <- any(nzchar(latex_engines))

if (latex_available && file.exists("thesis/build_latex.ps1")) {
  cat("\nBuilding direct LaTeX manuscript...\n")
  powershell_path <- Sys.which("powershell")

  if (nzchar(powershell_path)) {
    latex_output <- system2(
      powershell_path,
      c("-ExecutionPolicy", "Bypass", "-File", "thesis/build_latex.ps1"),
      stdout = TRUE,
      stderr = TRUE
    )
    cat(paste(latex_output, collapse = "\n"), "\n\n")

    latex_status <- attr(latex_output, "status")
    if (is.null(latex_status)) {
      latex_status <- 0L
    }

    if (!identical(latex_status, 0L)) {
      warning("LaTeX build failed with exit status ", latex_status)
    }
  } else {
    warning("PowerShell was not found, so the LaTeX build script was not run.")
  }
} else {
  cat("\nNo LaTeX engine found. Direct LaTeX source is ready at report_main.tex\n")
  cat("Install TinyTeX, TeX Live, or MiKTeX then run:\n")
  cat("  pdflatex report_main.tex\n")
  cat("  bibtex report_main\n")
  cat("  pdflatex report_main.tex && pdflatex report_main.tex\n\n")
}

cat("========================================\n")
cat("FULL PIPELINE COMPLETE\n")
cat("Finished:", format(Sys.time()), "\n")
cat("\nOutputs:\n")
cat("  Figures (all):  figures/\n")
cat("  Raw data:       data/raw/\n")
cat("  Processed data: data/processed/\n")
cat("  Regression tbl: output/tables/\n")
cat("  LaTeX report:   report_main.tex  (compile to get PDF)\n")
cat("  Quarto report:  analysis.qmd     (quarto render)\n")
cat("========================================\n")

