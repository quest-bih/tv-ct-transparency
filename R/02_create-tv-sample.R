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

  # Limit to trials from Charité
  filter(str_detect(lead_cities, "Berlin")) %>%

  # Reapply IV inclusion criteria
  filter(iv_completion, iv_status, iv_interventional) %>%

  # For trials included in both IV 1 & 2, select which to keep

  # First, limit to trials which were included in IV2 and put IV2 on top
  group_by(id) %>%
  filter(any(iv_version == 2)) %>%
  arrange(desc(iv_version)) %>%

  # If same publication for both IV 1 & 2, keep IV2 version
  distinct(id, doi, pmid, .keep_all = TRUE) %>%
  ungroup() %>%

  # If different publications for IV 1 & 2, manually remove a version
  # https://docs.google.com/spreadsheets/d/1RufE5pZL5PlBWx4SOryGbZ_DZxv2d5xuBQ6vcE4EDWk/edit#gid=288586668
  filter(
    !(id == "NCT00850629" & iv_version == 1),
    !(id == "NCT01049100" & iv_version == 1),
    !(id == "NCT01105143" & iv_version == 1),
    !(id == "NCT01181401" & iv_version == 1),
    !(id == "NCT01605487" & iv_version == 2)
  ) %>%

  # Check that only one row per id, and remove `iv_version`
  assert(is_uniq, id) %>%
  select(-iv_version) %>%

  # Update ft status for trial with ft not currently parsed in intovalue-data
  # Checked for crossreg in ft -> 2013-002319-82 TODO: add to crossreg
  # TODO: update in intovalue-data with bcg and grobid
  rows_update(tibble(
    id = "NCT01984788",
    has_ft = TRUE,
    ft_source = "doi",
    has_iv_trn_ft = FALSE
  ), by = "id") %>%

  # Checked for crossreg in ft -> none
  rows_update(tibble(
    id = "NCT01503372",
    has_ft = TRUE,
    ft_source = "doi",
    has_iv_trn_ft = TRUE # in ethics statement
  ), by = "id") %>%

  # Add link info for trial with publication with doi and no pmid: trackvalue %>% filter(publication_type == "journal publication") %>% filter(is.na(pmid) & !is.na(doi))
  # Checked for crossreg in ft -> none
  rows_update(tibble(
    id = "DRKS00004858",
    has_iv_trn_abstract = TRUE,
    has_iv_trn_ft = TRUE,
    has_reg_pub_link = FALSE
  ), by = "id") %>%

  # Add variable to record if days_reg_to_start is positive or negative (for report card)
  mutate(days_reg_to_start_is_positive = if_else(days_reg_to_start > 0, TRUE, FALSE))

# Check assumptions
# We expect all trials with summary results to have T/F for summary results timeliness
trackvalue %>%
  filter(has_summary_results) %>%
  assert(in_set(TRUE, FALSE, allow.na = FALSE), is_summary_results_1y, is_summary_results_2y)

# We expect all trials with publication to have T/F for publication metrics (timeliness, trn)
trackvalue %>%
  filter(has_publication) %>%
  assert(in_set(TRUE, FALSE, allow.na = FALSE),
         is_publication_2y,
         has_iv_trn_abstract,
         has_iv_trn_ft,
         has_reg_pub_link
  )

# NOTE: some trials with non-journal article publication have data for publication metrics --> disregarded in report cards via filtering for `has_publication`
trackvalue %>%
  count(!has_publication & is_publication_2y)

# Trials with publication but missing unpaywall/syp

missing_unpaywall <-
  trackvalue %>%
  filter(has_publication) %>%
  filter(is.na(is_oa)) %>%
  select(id, pmid, doi, url, is_oa)

missing_syp <-
  trackvalue %>%
  filter(has_publication) %>%
  filter(color == "closed") %>%
  filter(is.na(is_closed_archivable)) %>%
  select(id, pmid, doi, url, color, is_closed_archivable)

readr::write_csv(trackvalue, fs::path(dir, "trackvalue.csv"))


# CROSS-REGISTRATIONS -----------------------------------------------------

# Limit to cross-registrations of trials included in trackvalue
trackvalue_crossreg <-
  intovalue_crossreg %>%
  semi_join(trackvalue, by = c("id", "pmid", "doi")) %>%
  distinct()

readr::write_csv(trackvalue_crossreg, fs::path(dir, "crossreg.csv"))
