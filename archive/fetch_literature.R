library(httr)
library(jsonlite)

themes <- list(
  gvc_theory = "Global Value Chains OR global production networks",
  industrial_policy = "industrial policy OR developmental state",
  flying_geese = "flying geese model OR East Asian industrialization",
  china_plus_one = "China plus one OR supply chain restructuring",
  vietnam_thailand = "Vietnam industrialization OR Thailand Eastern Seaboard",
  sez_policy = "Special Economic Zones OR SEZ policy",
  bri_central_asia = "Belt and Road Initiative Central Asia OR BRI Uzbekistan",
  landlocked = "landlocked developing countries OR trade costs landlocked",
  uzbekistan_reforms = "Uzbekistan economic reforms OR Uzbekistan industrialization",
  fdi_tech_transfer = "foreign direct investment technology transfer OR FDI spillovers"
)

bibtex_entries <- c()
seen_dois <- c()

fetch_works <- function(query, max_results = 25) {
  url <- "https://api.openalex.org/works"
  
  # Ensure URL encoding of the query
  params <- list(
    search = query,
    filter = "publication_year:2020-2026,type:article|book-chapter",
    sort = "cited_by_count:desc",
    `per-page` = max_results,
    mailto = "research@example.com"
  )
  
  resp <- tryCatch({
    GET(url, query = params, timeout(30))
  }, error = function(e) NULL)
  
  if (is.null(resp) || status_code(resp) != 200) {
    cat(sprintf("Error fetching %s\n", query))
    return(list())
  }
  
  parsed <- fromJSON(content(resp, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  return(parsed$results)
}

format_bibtex <- function(work, theme) {
  doi <- work$doi
  if (is.null(doi) || doi %in% seen_dois) return(NULL)
  
  seen_dois <<- c(seen_dois, doi)
  
  doi_clean <- gsub("https://doi.org/", "", doi)
  bib_key <- gsub("[/\\.-]", "_", doi_clean)
  
  title <- work$title
  if (is.null(title)) title <- "Unknown Title"
  year <- work$publication_year
  
  authors <- sapply(work$authorships, function(x) {
    if (!is.null(x$author$display_name)) x$author$display_name else NA
  })
  authors <- authors[!is.na(authors)]
  author_str <- if (length(authors) > 0) paste(authors, collapse = " and ") else "Unknown"
  
  journal <- ""
  if (!is.null(work$primary_location) && !is.null(work$primary_location$source)) {
    journal <- work$primary_location$source$display_name
  }
  if (is.null(journal)) journal <- "Unknown Journal"
  
  # Basic escaping for latex
  title <- gsub("&", "\\\\&", title)
  journal <- gsub("&", "\\\\&", journal)
  
  lines <- c(
    sprintf("@article{%s,", bib_key),
    sprintf("  title = {%s},", title),
    sprintf("  author = {%s},", author_str),
    sprintf("  journal = {%s},", journal),
    sprintf("  year = {%s},", year),
    sprintf("  doi = {%s},", doi_clean),
    sprintf("  note = {Theme: %s}", theme),
    "}"
  )
  return(paste(lines, collapse = "\n"))
}

cat("Fetching literature from OpenAlex...\n")
for (theme_name in names(themes)) {
  query <- themes[[theme_name]]
  cat(sprintf("Querying for: %s\n", theme_name))
  
  works <- fetch_works(query, max_results = 25)
  for (w in works) {
    bib <- format_bibtex(w, theme_name)
    if (!is.null(bib)) {
      bibtex_entries <- c(bibtex_entries, bib)
    }
  }
  Sys.sleep(1) # rate limiting
}

writeLines(bibtex_entries, "references_expanded.bib")
cat(sprintf("Successfully generated references_expanded.bib with %d references.\n", length(bibtex_entries)))
