library(dplyr)
library(stringr)
library(readr)

intovalue <- read_csv(here::here("data", "raw", "intovalue.csv"))
crossreg <- read_csv(here::here("data", "raw", "intovalue-crossreg.csv"))

dir <- fs::dir_create(here::here("data", "processed"))


trackvalue <-
  intovalue %>%

  # Limit the trials to IV 2 from Charité
  filter(str_detect(lead_cities, "Berlin") & iv_version == 2) %>%
  # Reapply IV inclusion criteria
  filter(iv_completion, iv_status, iv_interventional)

readr::write_rds(trackvalue, fs::path(dir, "trackvalue.rds"))
readr::write_csv(trackvalue, fs::path(dir, "trackvalue.csv"))

# Limit to cross-registrations of trials included in trackvalue
trackvalue_crossreg <-
  crossreg %>%
  semi_join(trackvalue, by = c("id", "pmid", "doi")) %>%
  distinct()

readr::write_rds(trackvalue_crossreg, fs::path(dir, "crossreg.rds"))
