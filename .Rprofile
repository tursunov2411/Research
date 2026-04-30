if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
  project_root <- tryCatch(rstudioapi::getActiveProject(), error = function(e) NULL)

  if (!is.null(project_root) && nzchar(project_root)) {
    setwd(project_root)
  }
}

required_paths <- c("data/raw", "data/processed", "scripts", "output", "stata")
missing_paths <- required_paths[!dir.exists(required_paths)]

if (length(missing_paths) > 0) {
  warning(
    "R is not running from the uzbekistan_thesis project root. ",
    "Open uzbekistan_thesis.Rproj or setwd() to the thesis folder. ",
    "Missing paths: ",
    paste(missing_paths, collapse = ", "),
    call. = FALSE
  )
}
