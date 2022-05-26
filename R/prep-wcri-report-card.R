library(dplyr)
library(purrr)
library(tidyr)
library(readr)
library(here)

# Helper function to calculate duration in days
duration_days <- function(start, end){
  as.numeric(lubridate::as.duration(lubridate::interval(start, end)), "days")
}

trackvalue <-
  read_csv(here("data", "processed", "trackvalue-checked.csv"))


wcri_trial <- trackvalue %>%
  add_row(id = "NCT12345678") %>%
  filter(id == "NCT12345678") %>%
  mutate(
    registry = "ClinicalTrials.gov",
    title = "Impact of prolonged exposure to baby yoda on meta-researcher well-being",

    registration_date = "2018-02-15",
    start_date = "2018-03-15",
    completion_date = "2019-02-10",
    completion_year = "2019",

    is_prospective = TRUE,
    has_summary_results = FALSE,
    is_summary_results_1y = FALSE,
    days_reg_to_start = duration_days(registration_date, start_date),
    days_reg_to_start_is_positive = if_else(days_reg_to_start > 0, TRUE, FALSE),

    has_publication = TRUE,
    citation = "Prolonged baby yoda exposure improves meta-researcher well-being",
    doi = "10.1002/pmrj.12496",
    pmid = "32969166",
    url = "https://doi.org/10.1002/pmrj.12496",
    publication_date = "2020-10-28",
    is_publication_2y = TRUE,

    has_iv_trn_secondary_id = TRUE,
    has_iv_trn_abstract = TRUE,
    has_iv_trn_ft = TRUE,
    has_reg_pub_link = FALSE,

    is_oa = FALSE,
    is_closed_archivable = TRUE,

    # Cross-registration to EUCTR
    has_valid_crossreg_eudract = FALSE,
    registration_date_eudract = NA,
    start_date_eudract = NA,
    completion_date_eudract = NA,
    is_prospective_eudract = NA,
    has_summary_results_eudract = NA,
    is_summary_results_1y_eudract = NA
  )

write_csv(wcri_trial, here("data", "processed", "wcri-report-card.csv"))
