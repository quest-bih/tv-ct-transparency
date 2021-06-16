source(here::here("R", "environment.R"))

# Load dataset
trackvalue <-
  read_rds(here::here("data", "processed", "trackvalue.rds"))

trackvalue <- trackvalue %>%
  mutate(has_doi = if_else(!is.na(doi), TRUE, FALSE))

# Filter for trials with a publication and DOI, keep only unique DOIs
trackvalue_dois <- trackvalue %>%
  filter(has_publication, has_doi) %>%
  distinct(doi, .keep_all = TRUE)

# Query Unpaywall API with journal > respository hierarchy (except Bronze)
cols <- c("doi","color","issn","journal","publisher","date")
df <- data.frame(matrix(ncol = length(cols), nrow = 0))
colnames(df) <- cols

doi_batch <- trackvalue_dois[["doi"]]
print(paste0("DOI number: ", length(doi_batch)))

unpaywall_results <- unpaywallR::dois_OA_colors(doi_batch,
                                                email_api,
                                                clusters = 2,
                                                color_hierarchy = c("gold",
                                                                    "hybrid",
                                                                    "green",
                                                                    "bronze",
                                                                    "closed"))

oa_results <- tibble(doi = doi_batch,
                     color = unpaywall_results$OA_color,
                     issn = unpaywall_results$issn,
                     journal = unpaywall_results$journal,
                     publisher = unpaywall_results$publisher,
                     date = unpaywall_results$date)

df <- rbind(df, oa_results)

# Join back to initial table
all_results <- left_join(trackvalue, df, by = "doi")

test <- all_results %>%
  verify(nrow(.)==nrow(trackvalue))

write_csv(all_results, here::here("data", "processed", paste0(Sys.Date(), "_trackvalue-oa.csv")))
