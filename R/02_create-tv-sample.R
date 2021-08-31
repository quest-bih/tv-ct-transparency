library(dplyr)
library(stringr)
library(readr)

intovalue <- read_csv(here::here("data", "raw", "intovalue.csv"))
intovalue_crossreg <- read_csv(here::here("data", "raw", "intovalue-crossreg.csv"))

dir <- fs::dir_create(here::here("data", "processed"))


trackvalue <-
  intovalue %>%

  # Limit the trials to IV 2 from Charité
  filter(str_detect(lead_cities, "Berlin") & iv_version == 2) %>%

  # Reapply IV inclusion criteria
  filter(iv_completion, iv_status, iv_interventional) %>%

  # # Trials with a journal article have a publication (disregard dissertations and abstracts)
  mutate(has_publication = if_else(publication_type == "journal publication", TRUE, FALSE, missing = FALSE))

readr::write_csv(trackvalue, fs::path(dir, "trackvalue.csv"))

# Limit to cross-registrations of trials included in trackvalue
trackvalue_crossreg <-
  intovalue_crossreg %>%
  semi_join(trackvalue, by = c("id", "pmid", "doi")) %>%
  distinct()

readr::write_csv(trackvalue_crossreg, fs::path(dir, "crossreg.csv"))
