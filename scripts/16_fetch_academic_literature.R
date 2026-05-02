library(httr)
library(jsonlite)
library(dplyr)
library(stringr)

# 1. Setup Directories
dirs <- c("literature/raw", "literature/processed", "literature/bibtex", "literature/notes")
for (d in dirs) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# 2. Define High-Impact Target Journals
target_journals <- c(
  "world development",
  "journal of development economics",
  "global networks",
  "journal of international business studies",
  "review of international political economy",
  "third world quarterly",
  "economic geography",
  "cambridge journal of economics",
  "technological forecasting and social change",
  "asian survey",
  "eurasian geography and economics",
  "post-communist economies",
  "research policy",
  "journal of economic geography",
  "international affairs"
)

# 3. Define Themes and Queries
themes <- list(
  gvc_theory = c("global value chain", "global production network", "value capture"),
  developmental_state = c("developmental state", "industrial policy", "structural transformation"),
  east_asian_mfg = c("flying geese", "east asian industrialization", "export-oriented industrialization"),
  vietnam_thailand = c("vietnam industrialization", "thailand eastern seaboard", "china plus one"),
  central_asia = c("central asia industrialization", "uzbekistan economy", "eurasian logistics integration"),
  sez_fdi = c("special economic zone", "foreign direct investment manufacturing", "technology transfer")
)

# 4. OpenAlex API function with strict filtering
fetch_openalex <- function(query_phrase, max_results = 50) {
  url <- "https://api.openalex.org/works"
  
  # Search within title or abstract, filter to articles/chapters, year 2019-2026, has DOI
  # Note: OpenAlex uses default.search for title, abstract, full text.
  # We will use title.search for higher precision, or default.search and then filter by journal.
  
  params <- list(
    `filter` = paste0("publication_year:2019-2026,type:article,has_doi:true,default.search:", gsub(" ", "+", query_phrase)),
    sort = "cited_by_count:desc",
    `per-page` = max_results,
    mailto = "research@example.com"
  )
  
  resp <- tryCatch({
    GET(url, query = params, timeout(60))
  }, error = function(e) { cat("Error:", e$message, "\n"); return(NULL) })
  
  if (is.null(resp) || status_code(resp) != 200) {
    return(list())
  }
  
  parsed <- fromJSON(content(resp, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  return(parsed$results)
}

# 5. Process and Filter Results
all_works <- list()
seen_dois <- c()

cat("Fetching literature from OpenAlex...\n")
for (theme in names(themes)) {
  for (phrase in themes[[theme]]) {
    cat(sprintf("  Querying [%s]: %s\n", theme, phrase))
    results <- fetch_openalex(phrase, max_results = 50)
    
    for (res in results) {
      doi <- res$doi
      if (is.null(doi) || doi %in% seen_dois) next
      
      journal_name <- tolower(res$primary_location$source$display_name)
      if (is.null(journal_name)) next
      
      # Strict Quality Filter: Only keep if in target journals OR highly cited (>20 citations)
      is_target_journal <- any(sapply(target_journals, function(j) grepl(j, journal_name, fixed=TRUE)))
      cited_count <- res$cited_by_count
      if (is.null(cited_count)) cited_count <- 0
      
      if (is_target_journal || cited_count >= 15) {
        seen_dois <- c(seen_dois, doi)
        
        # Extract metadata
        authors <- sapply(res$authorships, function(x) x$author$display_name)
        author_str <- paste(authors[!sapply(authors, is.null)], collapse = " and ")
        
        all_works[[length(all_works) + 1]] <- list(
          id = res$id,
          title = res$title,
          doi = gsub("https://doi.org/", "", doi),
          author = author_str,
          journal = res$primary_location$source$display_name,
          year = res$publication_year,
          citations = cited_count,
          theme = theme,
          abstract = res$abstract_inverted_index # Not parsing full abstract for now to save space
        )
      }
    }
    Sys.sleep(0.5) # Be polite to API
  }
}

# 6. Convert to Dataframe and Save
if (length(all_works) > 0) {
  df <- bind_rows(lapply(all_works, function(w) {
    data.frame(
      id = w$id,
      title = w$title,
      author = w$author,
      journal = w$journal,
      year = w$year,
      doi = w$doi,
      citations = w$citations,
      theme = w$theme,
      stringsAsFactors = FALSE
    )
  }))
  
  # Remove duplicates just in case
  df <- df %>% distinct(doi, .keep_all = TRUE)
  
  # Sort by theme and citations
  df <- df %>% arrange(theme, desc(citations))
  
  # Save Raw & Processed Data
  write.csv(df, "literature/processed/literature_database.csv", row.names = FALSE)
  saveRDS(all_works, "literature/raw/openalex_raw.rds")
  
  cat(sprintf("\nRetrieved %d highly relevant, peer-reviewed articles.\n", nrow(df)))
  
  # 7. Generate BibTeX
  bibtex_lines <- c()
  for (i in 1:nrow(df)) {
    row <- df[i, ]
    bib_key <- gsub("[/\\.-]", "_", row$doi)
    
    title_clean <- gsub("&", "\\\\&", row$title)
    journal_clean <- gsub("&", "\\\\&", row$journal)
    
    bib <- sprintf(
      "@article{%s,\n  title = {%s},\n  author = {%s},\n  journal = {%s},\n  year = {%s},\n  doi = {%s},\n  note = {Theme: %s},\n  addendum = {Citations: %s}\n}\n",
      bib_key, title_clean, row$author, journal_clean, row$year, row$doi, row$theme, row$citations
    )
    bibtex_lines <- c(bibtex_lines, bib)
  }
  
  writeLines(bibtex_lines, "literature/bibtex/dissertation_references.bib")
  
  # 8. Generate Annotated Bibliography / Notes
  notes_lines <- c("# Annotated Bibliography & Literature Clusters\n")
  for (t in unique(df$theme)) {
    notes_lines <- c(notes_lines, sprintf("\n## Theme: %s\n", toupper(t)))
    theme_df <- df %>% filter(theme == t) %>% arrange(desc(citations)) %>% head(15) # Top 15 per theme
    
    for (i in 1:nrow(theme_df)) {
      notes_lines <- c(notes_lines, sprintf("### %s (%s)", theme_df$title[i], theme_df$year[i]))
      notes_lines <- c(notes_lines, sprintf("**Authors:** %s", theme_df$author[i]))
      notes_lines <- c(notes_lines, sprintf("**Journal:** %s | **Citations:** %s | **DOI:** %s\n", 
                                            theme_df$journal[i], theme_df$citations[i], theme_df$doi[i]))
      notes_lines <- c(notes_lines, "*(Insert synthesis/annotation here)*\n")
    }
  }
  
  writeLines(notes_lines, "literature/notes/annotated_bibliography.md")
  cat("Successfully generated BibTeX and Annotated Bibliography in /literature directory.\n")
} else {
  cat("No literature retrieved. Check queries and API status.\n")
}
