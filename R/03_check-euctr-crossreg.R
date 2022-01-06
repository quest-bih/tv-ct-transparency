library(dplyr)
library(stringr)
library(here)
library(readr)
library(fs)

trackvalue <-  read_csv(here("data", "processed", "trackvalue.csv"))
crossreg <-  read_csv(here("data", "processed", "crossreg.csv"))

# `has_crossreg_eudract` reflects eudract ids mentioned in registration, not in publication, so misses some trials (n = 9) with potential euctr cross-registrations
# https://github.com/maia-sh/intovalue-data/blob/main/scripts/14_prepare-trials.R#L246
tv_euctr_crossreg_in_reg <- filter(trackvalue, has_crossreg_eudract)

tv_euctr_crossreg_not_in_reg <-
  crossreg %>%
  filter(crossreg_registry == "EudraCT") %>%
  distinct(id) %>%
  anti_join(filter(trackvalue, has_crossreg_eudract), by = "id")

# Instead, use `crossreg` for most comprehensive list of potential euctr cross-registrations
tv_euctr_crossreg <-
  crossreg %>%
  filter(crossreg_registry == "EudraCT") %>%
  arrange(id)

# How many potential euctr cross-registrations?
nrow(tv_euctr_crossreg)

# How many trials with potential euctr cross-registration(s)?
n_distinct(tv_euctr_crossreg$id)

# Gather PDFs for included trials
# Note: Assume `intovalue-data` repo in same parent directory with PDFs available
# PDFs unavailable for: 10.1055/s-0037-1607119; 10.1200/jco.2016.34.15_suppl.6035; 10.1200/jco.2018.36.5_suppl.61

tv_pdf_dir <-
  dir_create(here("data", "manual", "euctr-crossreg-pdfs"))

iv_pdf_dir <-
  path(path_abs(".."), "intovalue-data", "data", "raw", "fulltext", "doi", "pdf")

pdf_paths <-
  tv_euctr_crossreg %>%
  filter(!is.na(doi)) %>%
  distinct(doi) %>%
  arrange(doi) %>%
  pull(doi) %>%
  str_replace_all("/", "\\+") %>%
  str_c(., ".pdf")

iv_pdf_paths <- path(iv_pdf_dir, pdf_paths)
tv_pdf_paths <- path(tv_pdf_dir, pdf_paths)

file_copy(iv_pdf_paths, tv_pdf_paths)

# Prepare csv of potential euctr cross-registrations for manual verification
# EUCTR link preferably to national protocol mentioning primary registration, and DE if possible
tv_euctr_crossreg %>%
  mutate(valid_crossreg = NA, euctr_link = NA, results = NA, comments = NA) %>%
  write_csv(here("data", "manual", "euctr-crossreg.csv"))


# Search for tv ctgov and drks trns in euctr
# Manually add any additional cross-registrations to "euctr-crossreg.csv"
euctr_query <- "https://www.clinicaltrialsregister.eu/ctr-search/search?query="

drks_euctr_query <-
  trackvalue %>%
  filter(registry == "DRKS") %>%
  pull(id) %>%
  str_remove("^DRKS") %>%
  str_c(collapse = "+OR+") %>%
  str_c(euctr_query, "DRKS+AND+(", ., ")")

ctgov_euctr_query <-
  trackvalue %>%
  filter(registry == "ClinicalTrials.gov") %>%
  pull(id) %>%
  str_c(collapse = "+OR+") %>%
  str_c(euctr_query, .)
