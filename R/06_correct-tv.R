# Via trialist feedback (survey/emails), we discovered some corrections to the dataset, including a bug in the DRKS links code. We update the report cards for reminder 2 to reflect this. We also edit the reminder email for these trials.

# Corrected via IntoValue:
# "DRKS00009368" # add drks link
# "DRKS00009391" # add drks link
# "DRKS00009539" # add drks link
# "DRKS00012795" # add drks link
# "DRKS00004649" # add drks link
# "DRKS00003568" # add drks link (no doi/pmid link)
# "NCT01984788"  # add euctr crossreg (2013-002319-82)

# Corrected manually:
# "NCT02509962" # add publication (10.1038/nature24628) and links/oa
# "NCT01266655" # change publication (10.1016/j.euroneuro.2015.04.002), change links/oa, add euctr crossreg (2010-021861-62)

# No report card correction:
# "DRKS00012665" add drks link but no pub in iv data


library(dplyr)
library(tidyr)
library(stringr)
library(here)
library(readr)
library(fs)

trackvalue <-
  read_csv(here("data", "processed", "trackvalue-checked.csv"))

tv_old <-
  read_csv(here("data", "timestamped", "2022-06-03_reminder-1", "2022-06-03_trackvalue-checked.csv"))

# Compare old and corrected trackvalue
waldo::compare(tv_old, trackvalue)

# Inspect differences
trackvalue %>%
  anti_join(tv_old) %>%
  count(registry, has_publication, has_reg_pub_link)

# Manually correct trials
trackvalue_corrected <-
  trackvalue %>%

  # "NCT02509962" add publication (10.1038/nature24628) and links/oa
  rows_update(
    tibble(
      id = "NCT02509962",
      has_publication = TRUE,
      doi = "10.1038/nature24628",
      url = "https://www.nature.com/articles/nature24628",
      is_publication_2y = TRUE,
      citation = "Wilck et al. (2017) Salt-responsive gut commensal modulates TH17 axis and disease",
      has_iv_trn_abstract = FALSE,
      has_iv_trn_secondary_id = FALSE,
      has_iv_trn_ft = TRUE,
      has_reg_pub_link = FALSE, # updated since intervention
      is_oa = TRUE,
      is_closed_archivable = NA,
    ),
    by = "id"
  ) %>%

  # "NCT01266655" change publication (10.1016/j.euroneuro.2015.04.002), change links/oa, add euctr crossreg (2010-021861-62)
  rows_update(
    tibble(
      id = "NCT01266655",
      doi = "10.1016/j.euroneuro.2015.04.002",
      url = "https://doi.org/10.1016/j.euroneuro.2015.04.002",
      is_publication_2y = TRUE,
      citation = "Müller et al. (2015) High-dose baclofen for the treatment of alcohol dependence (BACLAD study): A randomized, placebo-controlled trial",
      has_iv_trn_abstract = FALSE,
      has_iv_trn_secondary_id = FALSE,
      has_iv_trn_ft = FALSE,
      has_reg_pub_link = FALSE,
      is_oa = FALSE,
      is_closed_archivable = TRUE,

      trn_eudract = "2010-021861-62",
      has_valid_crossreg_eudract = TRUE,
      is_prospective_eudract = TRUE,
      has_summary_results_eudract = TRUE
    ),
    by = "id"
  )

write_csv(trackvalue_corrected, here("data", "processed", "trackvalue-checked.csv"))
