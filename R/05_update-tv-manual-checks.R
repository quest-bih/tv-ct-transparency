# Update trackvalue to reflect manual checks on cross-registrations and open access

library(dplyr)
library(here)
library(readr)

trackvalue <-  read_csv(here("data", "processed", "trackvalue.csv"))
euctr_crossreg <- read_csv(here("data", "processed", "crossreg-euctr-data.csv"))
oa_checks <- read_csv(here("data", "manual", "oa-checks.csv"))

trackvalue_checked <-
  trackvalue %>%

  # Remove crossreg columns since irrelevant
  select(-starts_with("has_crossreg"), -starts_with("n_crossreg")) %>%

  # Add in euctr crossreg data based on manual checks and euctr webscraper
  left_join(euctr_crossreg, by = "id") %>%

  # Recode trials without euctr crossreg to false
  mutate(has_valid_crossreg_eudract = tidyr::replace_na(has_valid_crossreg_eudract, FALSE)) %>%

  # Update open access based on manual checks
  rows_update(oa_checks, by = c("id", "doi"))

write_csv(trackvalue_checked, here("data", "processed", "trackvalue-checked.csv"))
