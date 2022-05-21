# Update trackvalue to reflect manual checks on cross-registrations and open access

library(dplyr)
library(here)
library(readr)

trackvalue <-  read_csv(here("data", "processed", "trackvalue.csv"))
euctr_crossreg <- read_csv(here("data", "processed", "crossreg-euctr-data.csv"))

trackvalue_checked <-
  trackvalue %>%

  # Remove crossreg columns since irrelevant
  select(-starts_with("has_crossreg"), -starts_with("n_crossreg")) %>%

  # Add in euctr crossreg data
  left_join(euctr_crossreg, by = c("id" = "trn"))

# TODO: delwen add oa

write_csv(trackvalue_checked, here("data", "processed", "trackvalue-checked.csv"))
