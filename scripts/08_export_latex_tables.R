# ============================================================
# Script: 08_export_latex_tables.R
# Purpose: Export statistical CSV outputs as LaTeX table inputs
# ============================================================

dir.create("thesis/tables", recursive = TRUE, showWarnings = FALSE)

escape_latex <- function(x) {
  x <- ifelse(is.na(x), "--", as.character(x))
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("&", "\\\\&", x)
  x <- gsub("%", "\\\\%", x)
  x <- gsub("\\$", "\\\\$", x)
  x <- gsub("#", "\\\\#", x)
  x <- gsub("_", "\\\\_", x)
  x <- gsub("\\{", "\\\\{", x)
  x <- gsub("\\}", "\\\\}", x)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  x <- gsub("\\^", "\\\\textasciicircum{}", x)
  x
}

write_latex_table <- function(data, path, caption, label, align = NULL) {
  if (is.null(align)) {
    align <- paste(rep("l", ncol(data)), collapse = "")
  }

  data[] <- lapply(data, function(column) {
    column <- ifelse(is.na(column), "--", column)
    as.character(column)
  })

  header <- paste(escape_latex(names(data)), collapse = " & ")
  rows <- apply(data, 1, function(row) {
    paste(escape_latex(row), collapse = " & ")
  })

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    paste0("\\caption{", escape_latex(caption), "}"),
    paste0("\\label{", label, "}"),
    "\\resizebox{\\textwidth}{!}{%",
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    paste0(rows, " \\\\"),
    "\\bottomrule",
    "\\end{tabular}%",
    "}",
    "\\end{table}"
  )

  writeLines(lines, path, useBytes = TRUE)
}

read_table <- function(path) {
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

country_summary <- read_table("output/tables/table_descriptive_country_summary.csv")
country_summary <- country_summary[, c(
  "country_code",
  "country",
  "years",
  "mean_manuf_va_gdp",
  "mean_fdi_gdp",
  "mean_gdp_per_capita",
  "mean_lpi_score"
)]
write_latex_table(
  country_summary,
  "thesis/tables/descriptive_country_summary.tex",
  "Country-level descriptive statistics, 2010-2023",
  "tab:descriptive-country",
  "lllrrrr"
)

pre_post <- read_table("output/tables/table_uzbekistan_pre_post.csv")
write_latex_table(
  pre_post,
  "thesis/tables/uzbekistan_pre_post.tex",
  "Uzbekistan pre- and post-reform summary",
  "tab:uzbekistan-pre-post",
  "llrrrr"
)

trend <- read_table("output/tables/table_trend_regressions_robust.csv")
trend <- trend[, c("outcome", "term", "estimate", "robust_se", "statistic", "p_value")]
write_latex_table(
  trend,
  "thesis/tables/trend_regressions_robust.tex",
  "Trend regressions with robust standard errors",
  "tab:trend-regressions",
  "llrrrr"
)

chow <- read_table("output/tables/table_chow_test.csv")
write_latex_table(
  chow,
  "thesis/tables/chow_test.tex",
  "Chow structural break test at the 2017 reform breakpoint",
  "tab:chow-test",
  "lrrrl"
)

rca <- read_table("output/tables/table_rca_diversification.csv")
write_latex_table(
  rca,
  "thesis/tables/rca_diversification.tex",
  "Uzbekistan RCA diversification indicators",
  "tab:rca-diversification",
  "rrr"
)

comparison <- read_table("output/tables/table_comparison_scorecard.csv")
write_latex_table(
  comparison,
  "thesis/tables/comparison_scorecard.tex",
  "Comparative reform-stage scorecard",
  "tab:comparison-scorecard",
  "lrrrrrr"
)

if (file.exists("output/tables/table_scenario_2030.csv")) {
  scenario_2030 <- read_table("output/tables/table_scenario_2030.csv")
  write_latex_table(
    scenario_2030,
    "thesis/tables/scenario_2030.tex",
    "Scenario projections for 2030",
    "tab:scenario-2030",
    "lrrr"
  )
}

if (file.exists("output/tables/table_scenario_target_years.csv")) {
  scenario_targets <- read_table("output/tables/table_scenario_target_years.csv")
  write_latex_table(
    scenario_targets,
    "thesis/tables/scenario_target_years.tex",
    "Scenario benchmark target years",
    "tab:scenario-target-years",
    "llrr"
  )
}

cat("LaTeX table inputs exported to thesis/tables/.\n")
