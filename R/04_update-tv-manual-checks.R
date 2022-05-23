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
  left_join(euctr_crossreg, by = "id") %>%

  # accessible version of publication found on journal website
  rows_update(tibble(
    doi = "10.1016/j.jaci.2016.03.043",
    color = "open-unclear",
    color_green_only = "open-unclear",
    is_oa = TRUE,
    is_closed_archivable = NA
    ), by = "doi") %>%

  # accessible version of publication found on journal website
  rows_update(tibble(
    doi = "10.1097/eja.0000000000000929",
    color = "open-unclear",
    color_green_only = "open-unclear",
    is_oa = TRUE,
    is_closed_archivable = NA
    ), by = "doi") %>%

  # accessible version of publication found in Refubium
  rows_update(tibble(
    doi = "10.1017/s0033291716001379",
    color = "green",
    color_green_only = "green",
    is_oa = TRUE,
    is_closed_archivable = NA
    ), by = "doi") %>%

  # accessible version of publication found on journal website
  rows_update(tibble(
    doi = "10.1016/j.jaci.2012.06.047",
    color = "open-unclear",
    color_green_only = "open-unclear",
    is_oa = TRUE,
    is_closed_archivable = NA
    ), by = "doi") %>%

  # accessible version of publication found on journal website
  rows_update(tibble(
    doi = "10.1200/jco.2011.41.1553",
    color = "open-unclear",
    color_green_only = "open-unclear",
    is_oa = TRUE,
    is_closed_archivable = NA
    ), by = "doi")

write_csv(trackvalue_checked, here("data", "processed", "trackvalue-checked.csv"))
