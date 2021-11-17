library(dplyr)
library(stringr)
library(readr)
library(assertr)

intovalue <- read_csv(here::here("data", "raw", "intovalue.csv"))
intovalue_crossreg <- read_csv(here::here("data", "raw", "intovalue-crossreg.csv"))

dir <- fs::dir_create(here::here("data", "processed"))


# TRACK VALUE -------------------------------------------------------------

trackvalue <-
  intovalue %>%

  # Limit the trials to IV 2 from Charité
  filter(str_detect(lead_cities, "Berlin") & iv_version == 2) %>%

  # Reapply IV inclusion criteria
  filter(iv_completion, iv_status, iv_interventional) %>%

  # Abstracts miscoded as journal article
  # Could also change in `intovalue-data`
  mutate(publication_type = if_else(id %in% c("NCT01600573", "NCT02052960", "NCT01770080", "NCT01181401"), "abstract", publication_type)) %>%

  # DOI/PMID missing for one journal article (letter, no abstract)
  # Also has a cross-registration: 2013-002319-82
  # Could also change in `intovalue-data`: filter(intovalue, publication_type == "journal publication" & !is.na(url) & is.na(doi))
  rows_update(tibble(
    id = "NCT01984788",
    doi = "10.1016/j.jaci.2016.03.043",
    pmid = 27302552,
    has_iv_trn_abstract = FALSE,
    has_iv_trn_ft = TRUE,
    has_reg_pub_link = FALSE
  ), by = "id") %>%

  rows_update(tibble(
    id = "DRKS00004858",
    has_iv_trn_abstract = TRUE,
    has_iv_trn_ft = TRUE,
    has_reg_pub_link = FALSE
  ), by = "id") %>%

  # Trials with a journal article have a publication (disregard dissertations and abstracts)
  mutate(has_publication = if_else(publication_type == "journal publication", TRUE, FALSE, missing = FALSE))

# Check assumptions
# We expect all trials with summary results to have T/F for summary results timeliness
trackvalue %>%
  filter(has_summary_results) %>%
  assert(in_set(TRUE, FALSE, allow.na = FALSE), is_summary_results_1y, is_summary_results_2y)

# We expect all trials with publication to have T/F for publication metrics (timeliness, trn, open access)
trackvalue %>%
  filter(has_publication) %>%
  assert(in_set(TRUE, FALSE, allow.na = FALSE),
         is_publication_2y,
         has_iv_trn_abstract,
         has_iv_trn_ft,
         has_reg_pub_link,
         # is_oa, #TODO: DELWEN
         # is_closed_archivable #TODO: DELWEN
  )

# NOTE: some trials with non-journal article publication have data for publication metrics; could convert to NA or simply disregard via filtering
trackvalue %>%
  count(!has_publication & is_publication_2y)

# Trials with publication but missing unpaywall/syp
# TODO:Delwen, resolve these either by filling in missing data or clarifying meaning of NA so clear in report card
#
# missing_unpaywall <-
#   trackvalue %>%
#   filter(has_publication) %>%
#   filter(is.na(is_oa)) %>%
#   select(id, pmid, doi, url, is_oa)
#
# missing_syp <-
#   trackvalue %>%
#   filter(has_publication) %>%
#   filter(is.na(is_closed_archivable)) %>%
#   select(id, pmid, doi, url, is_oa)

readr::write_csv(trackvalue, fs::path(dir, "trackvalue.csv"))


# CROSS-REGISTRATIONS -----------------------------------------------------

# Limit to cross-registrations of trials included in trackvalue
trackvalue_crossreg <-
  intovalue_crossreg %>%
  semi_join(trackvalue, by = c("id", "pmid", "doi")) %>%
  distinct()

readr::write_csv(trackvalue_crossreg, fs::path(dir, "crossreg.csv"))
