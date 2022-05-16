library(dplyr)
library(stringr)
library(here)
library(readr)
library(fs)
library(glue)
library(googlesheets4)
library(daff)

trackvalue <-  read_csv(here("data", "processed", "trackvalue.csv"))
crossreg <-  read_csv(here("data", "processed", "crossreg.csv"))

crossreg_dir <- dir_create(here("data", "manual", "crossreg"))

# Explore potential cross-registrations -----------------------------------

# `has_crossreg_[REGISTRY]` reflects trns mentioned in registration, not in publication, so misses some trials with potential cross-registrations
# https://github.com/maia-sh/intovalue-data/blob/main/scripts/14_prepare-trials.R#L246
tv_crossreg_in_reg <-
  trackvalue %>%
  filter(if_any(starts_with("has_crossreg"), ~ . == TRUE))

tv_crossreg_in_reg %>% count(across(starts_with("has_crossreg")))

# Instead, use `crossreg` for most comprehensive list of potential cross-registrations
crossreg %>%
  group_by(crossreg_registry) %>%
  count(across(starts_with("is_crossreg")))

# How many potential cross-registrations?
nrow(crossreg)

# How many trials with potential cross-registration(s)?
n_distinct(crossreg$id)

# How many potential cross-registrations from which registry?
crossreg %>%
  count(crossreg_registry, name = "n_crossreg") %>%
  arrange(desc(n_crossreg))

# How many trials have how many cross-registrations?
crossreg %>%
  count(id, name = "n_crossreg_per_trial") %>%
  count(n_crossreg_per_trial, name = "n_trials")

# Check for "primary" trns in cross-registrations --> if true cross-reg, need to deduplicate in dataset
# DRKS00005219 (in IntoValue)/NCT02071615 (in IntoValue)/2012-003882-17
intersect(crossreg$id, crossreg$crossreg_trn)
semi_join(crossreg, crossreg, by = c("id" = "crossreg_trn"))
semi_join(crossreg, crossreg, by = c("crossreg_trn" = "id"))


# Search for tv ctgov and drks trns in euctr ------------------------------

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


# Gather pdfs for potential cross-registrations ---------------------------

# Note: Assume `intovalue-data` repo in same parent directory with PDFs available
# PDFs unavailable for some trials

tv_pdf_dir <-
  dir_create(crossreg_dir, "pdfs")

iv_pdf_dir <-
  path(path_abs(".."), "intovalue-data", "data", "raw", "fulltext", "doi", "pdf")

pdf_paths <-
  crossreg %>%
  filter(!is.na(doi)) %>%
  distinct(doi) %>%
  arrange(doi) %>%
  pull(doi) %>%
  str_replace_all("/", "\\+") %>%
  str_c(., ".pdf")

iv_pdf_paths <- path(iv_pdf_dir, pdf_paths)
tv_pdf_paths <- path(tv_pdf_dir, pdf_paths)

file_copy(iv_pdf_paths, tv_pdf_paths)


# Prepare csv of potential cross-registrations for manual checks ----------

# Prepare extraction columns
crossreg_extraction_columns <- tibble(
  resolves = "", #TRUE/FALSE
  matches = "", #TRUE/FALSE (same trial, same participants)
  non_match_source = "", #iv_registration, publication, crossreg_registration, other
  non_match_rationale = "", #free text: explanation why categorized as non-match, may be quote
  has_summary_results = "", #TRUE/FALSE
  start_date = "", #DATE
  registration_date = "", #DATE
  completion_date = "", #DATE
  more_crossreg = "", #free text; semicolon-separated list of any additional crossreg mentioned
  comments = "", #free text
)

# Solution from https://stackoverflow.com/a/70033706/6149975
# Collapse rows across group and remove duplicates and NAs
paste_rows <- function(x) {
  unique_x <- unique(x[!is.na(x)])
  if (length(unique_x) == 0) {
    unique_x <- NA
  }

  str_c(unique_x, collapse = "; ") %>%
    str_split("; ") %>%
    unlist() %>%
    unique() %>%
    str_c(collapse = "; ")

}

# Prepare extraction csv
crossreg_extractions <-
  crossreg %>%

  # Prepare URLs
  mutate(
    id_url = if_else(
      str_detect(id, "^NCT"),
      glue("https://clinicaltrials.gov/ct2/show/{id}"),
      glue("https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID={id}")
    ),

    crossreg_trn_url = case_when(
      crossreg_registry == "ClinicalTrials.gov" ~
        glue("https://clinicaltrials.gov/ct2/show/{crossreg_trn}"),
      crossreg_registry == "DRKS" ~
        glue("https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID={crossreg_trn}"),
      crossreg_registry == "EudraCT" ~
        glue("https://www.clinicaltrialsregister.eu/ctr-search/search?query=eudract_number:{crossreg_trn}"),
      crossreg_registry == "ISRCTN" ~
        glue("https://doi.org/10.1186/{crossreg_trn}")
    ),

    pmid = if_else(
      !is.na(pmid),
      glue('=HYPERLINK("https://pubmed.ncbi.nlm.nih.gov/{pmid}","{pmid}")'),
      NA_character_
    ),
    doi = if_else(
      !is.na(doi),
      glue('=HYPERLINK("https://doi.org/{doi}","{doi}")'),
      NA_character_
    ),
    id_url = glue('=HYPERLINK("{id_url}","{id}")'),
    crossreg_trn_url = glue('=HYPERLINK("{crossreg_trn_url}","{crossreg_trn}")')
  ) %>%

  # Add count of crossreg per primary id
  group_by(id) %>%
  mutate(n_crossreg = row_number()) %>%
  ungroup() %>%

  select(
    id,
    crossreg_trn,
    id_url,
    pmid,
    doi,
    n_crossreg,
    crossreg_trn_url,
    crossreg_registry,
    starts_with("is_crossreg")
  ) %>%
  arrange(id) %>%

  bind_cols(crossreg_extraction_columns)

write_csv(crossreg_extractions, path(crossreg_dir, "cross-registrations_to-extract.csv"))

codebook <-
  tibble(
    name = colnames(crossreg_extractions),
    extracted = if_else(name %in% colnames(crossreg_extraction_columns), TRUE, FALSE)
  )

description <- tribble(
  ~name, ~description,

  "id",
  "Trial registration number from IntoValue, either a ClinicalTrials.gov NCT id or DRKS id",

  "crossreg_trn",
  "Trial registration number of potential cross-registration of `id`. Found based on regular expresssions in one or more of the: `id` registrations, PubMed secondary identifier/metadata, abstract, full-text. May be a true cross-registration or a false positive, i.e., a related but separate trial",

  "id_url",
  "`id` formatted as hyperlink",

  "pmid",
  "PubMed identifier, formatted as hyperlink. Exceptionally may display as 'ERROR' if multiple hyperlinks due to `id` with different publications in IntoValue 1 and 2; in those cases, access each hyperlink by clicking into cell and copy-and-pasting into browser.",

  "doi",
  "Digital object identifier, formatted as hyperlink. Exceptionally may display as 'ERROR' if multiple hyperlinks due to `id` with different publications in IntoValue 1 and 2; in those cases, access each hyperlink by clicking into cell and copy-and-pasting into browser.",

  "n_crossreg",
  "Number of potential cross-registrations detected for `id`. One row per potential cross-registrations.",

  "crossreg_trn_url",
  "Potential cross-registration trial registration number, formatted as hyperlink",

  "crossreg_registry",
  "Potential cross-registration registry, formatted as hyperlink",

  "is_crossreg_secondary_id",
  "Whether `crossreg_trn` appears in PubMed secondary identifier/metadata. Usually TRUE or FALSE. NA if `id` has no publication with PMID and DOI. Exceptionally may be 'TRUE; FALSE' if `id` has different publications in IntoValue 1 and 2.",

  "is_crossreg_abstract",
  "Whether `crossreg_trn` appears in publication abstract in PubMed. Usually TRUE or FALSE. NA if `id` has no publication with PMID and DOI. Exceptionally may be 'TRUE; FALSE' if `id` has different publications in IntoValue 1 and 2.",

  "is_crossreg_ft",
  "Whether `crossreg_trn` appears in publication full-text (excluding abstract). Usually TRUE or FALSE. NA if `id` has no publication with PMID and DOI. Exceptionally may be 'TRUE; FALSE' if `id` has different publications in IntoValue 1 and 2.",

  "is_crossreg_reg",
  "Whether `crossreg_trn` appears in `id` registration. Usually TRUE or FALSE. NA if `id` has no publication with PMID and DOI. Exceptionally may be 'TRUE; FALSE' if `id` has different publications in IntoValue 1 and 2.",

  "resolves",
  "Logical. Whether `crossreg_trn_url` resolves to a registration.",

  "matches",
  "Logical. Whether `crossreg_trn` matches `id`, i.e. same trial. Coders use `non_match_source` to make this judgement. See Protocol for additional details on how trials were judged to be matching.",

  "non_match_source",
  "Categorical. 'iv_registration', 'publication', 'crossreg_registration', 'other'",

  "non_match_rationale",
  "Character. Reason for `matches` = FALSE. May be copied from `non_match_source`.",

  "has_summary_results",
  "Whether summary results were posted on `crossreg_trn` registry. ClinicalTrials.gov includes a structured summary results field. DRKS includes summary results with other references, and summary results were determined based on manual inspection with names such as Ergebnisbericht or Abschlussbericht. For other registries, see 'Trial Search Guide'",

  "start_date",
  "Date of the study start, as given on `crossreg_trn` registry. ClinicalTrials.gov previously allowed start dates without day, in which case date is defaulted to first of the month.",

  "registration_date",
  "Date of study submission to `crossreg_trn` registry, as given on `crossreg_trn` registry. As EUCTR does not provide a registration date, we used the *earliest* 'Date on which this record was first entered in the EudraCT database' found across all national protocols.",

  "completion_date",
  "Date of the study completion, as given on `crossreg_trn` registry. ClinicalTrials.gov previously allowed completion dates without day, in which case date is defaulted to first of the month. Indicated as `study end date` on DRKS.For EUCTR trials with results, we used the 'Global end of trial date' in the results; for EUCTR trials without results, we used the *latest* 'P. Date of the global end of the trial' found across all national protocols.",

  "more_crossreg",
  "Any additional potential cross-registrations foun",

  "comments",
  "Any comments"
)

codebook <-
  codebook %>%
  left_join(description, by = "name")

write_csv(codebook, path(crossreg_dir, "cross-registrations_codebook.csv"))

# Manually upload and format csvs to google sheets for extractions


# Download and compare dual-coded extractions -----------------------------

# Download extractions from google sheets
spreadsheet <- "https://docs.google.com/spreadsheets/d/1QdRmPfx0STqhDVcfPR_6wzdA1E8CZ0od5AW9SQKGw1E/edit#gid=1274917216"

msh_raw <- read_sheet(spreadsheet, "MSH", na = c("NA", "NULL", ""))
sy_raw <- read_sheet(spreadsheet, "SY", na = c("NA", "NULL", ""))

msh <-
  msh_raw %>%
  select(id, crossreg_trn, n_crossreg, resolves, matches, non_match_source, non_match_rationale, has_summary_results, start_date, registration_date, completion_date, more_crossreg, comments)

sy <-
  sy_raw %>%
  select(id, crossreg_trn, n_crossreg, resolves, matches, non_match_source, non_match_rationale, has_summary_results, start_date, registration_date, completion_date, more_crossreg, comments)

write_csv(msh, path(crossreg_dir, "cross-registrations_extracted-msh.csv"))
write_csv(sy, path(crossreg_dir, "cross-registrations_extracted-sy.csv"))

# Compare extraction
patch <- diff_data(msh, sy, show_unchanged = TRUE)
render_diff(patch)

# Manually reconcile extractions in google sheets


# Download reconciled, final extractions ----------------------------------
reconciled_raw <- read_sheet(spreadsheet, "Reconciled", na = c("NA", "NULL", ""))

reconciled <-
  reconciled_raw %>%
  select(id, crossreg_trn, n_crossreg, resolves, matches, non_match_source, non_match_rationale, has_summary_results, start_date, registration_date, completion_date, more_crossreg, comments)

write_csv(reconciled, path(crossreg_dir, "cross-registrations_reconciled.csv"))
