library(dplyr)
library(purrr)
library(tidyr)
library(readr)
library(here)
library(fs)
library(glue)
library(stringr)

# test_n <- 3

survey_link <- "https://s-quest.bihealth.org/limesurvey/index.php/966385"

dir_materials <- dir_create(here::here("communication-materials", "materials"))
dir_templates <- here::here("communication-materials", "templates")

trialists <-
  read_csv(here("data", "processed", "charite-contacts-per-trialist.csv"))

# How many trialists have how many trials?
count(trialists, n_trials)


# Prepare cross-registrations ---------------------------------------------

crossreg_raw <-  read_csv(here::here("data", "processed", "crossreg.csv"), show_col_types = FALSE)

crossreg <-
  crossreg_raw %>%
  filter(resolves & matches) %>%

  # Add NCT01266655 euctr crossreg (2010-021861-62)
  add_row(
    id = "NCT01266655",
    crossreg_trn = "2010-021861-62",
    crossreg_registry = "EudraCT"
  ) %>%

  mutate(
    crossreg_url = case_when(
      crossreg_registry == "ClinicalTrials.gov" ~
        paste0("https://clinicaltrials.gov/ct2/show/", crossreg_trn),
      crossreg_registry == "DRKS" ~
        paste0("https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID=", crossreg_trn),
      crossreg_registry == "EudraCT" ~
        paste0("https://www.clinicaltrialsregister.eu/ctr-search/search?query=eudract_number:", crossreg_trn),
      crossreg_registry == "ISRCTN" ~
        paste0("https://doi.org/10.1186/", crossreg_trn)
    ),

    crossreg_trn_md = glue::glue("[{crossreg_trn}]({crossreg_url})"),

    crossreg_trn_md = if_else(
      crossreg_registry == "EudraCT",
      glue::glue("EudraCT {crossreg_trn_md}"),
      crossreg_trn_md
    )
  ) %>%
  group_by(id) %>%
  mutate(
    crossreg = paste(sort(unique(unlist(crossreg_trn_md))), collapse = " und ")
  ) %>%
  ungroup() %>%
  distinct(id, crossreg) %>%
  mutate(crossreg = paste0(", sowie ", crossreg))


# Prepare trials ----------------------------------------------------------

trackvalue_raw <-
  read_csv(here("data", "processed", "trackvalue-checked.csv"))

trackvalue <-
  trackvalue_raw %>%
  select(id, registry, title, completion_year) %>%
  mutate(registration = if_else(
    registry == "ClinicalTrials.gov",
    paste0("https://clinicaltrials.gov/ct2/show/", id),
    paste0("https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID=", id)
  )) %>%
  left_join(crossreg, by = "id") %>%

  # Edit some problematic characters
  mutate(title =
           str_replace(title, "μg", "micrograms") %>%
           str_remove(., "\u0093")
  )


# Prepare 0 (launch): one trial -------------------------------------------

trialists_one_trial <-
  trialists %>%
  filter(n_trials == 1) %>%
  rename(
    id = ids,
    honorific = title
  ) %>%
  left_join(trackvalue, by = "id") %>%
  mutate(crossreg = replace_na(crossreg, ""))

render_0_one_trial <- function(name, id, registry, registration, title, completion_year, crossreg, name_for_file, survey_link, type, ...){

  if (!type %in% c("letter", "email")) stop("`type` must be 'letter' or 'email'")

  out_dir <- dir_create(path(dir_materials, glue("0_{type}")))
  out_file <- path(out_dir, name_for_file, ext = ifelse(type == "letter", "pdf", "md"))

  if (!file_exists(out_file)){
    rmarkdown::render(
      path(dir_templates, glue("0_{type}_one.Rmd")),
      params = list(
        name = name,
        id = id,
        registry = registry,
        registration = registration,
        title = title,
        completion_year = completion_year,
        crossreg = crossreg,
        survey_link = survey_link
      ),
      output_file = out_file
    )
  }

  if (type == "email"){
    try(file_copy(path(dir_templates, "template.html"), path(out_dir, "template.html"), overwrite = FALSE), silent = TRUE)
  }
}

trialists_one_trial %>%
  # slice_head(n = test_n) %>%
  purrr::pwalk(render_0_one_trial, survey_link = survey_link, type = "letter")

trialists_one_trial %>%
  # slice_head(n = test_n) %>%
  purrr::pwalk(render_0_one_trial, survey_link = survey_link, type = "email")


# Prepare 0 (launch): multi trial -----------------------------------------

trialists_multi_trial <-
  trialists %>%
  filter(n_trials > 1) %>%
  rename(honorific = title) %>%

  # Add trial info
  separate_rows(ids, sep = "; ") %>%
  rename(id = ids) %>%
  left_join(trackvalue, by = "id") %>%
  mutate(crossreg = replace_na(crossreg, "")) %>%
  group_by(name) %>%

  # Summarize trial info
  mutate(
    min_completion_year = min(completion_year, na.rm = TRUE),
    max_completion_year = max(completion_year, na.rm = TRUE),
    registries = paste(sort(unique(unlist(registry))), collapse = " und ")
  ) %>%

  # Prepare completion years text depending on whether one or more years
  mutate(
    completion_years = if_else(
      min_completion_year == max_completion_year,
      glue("in {min_completion_year}"),
      glue("zwischen {min_completion_year} und {max_completion_year}")
    )
  ) %>%

  # Nest trial info
  tidyr::nest(trials = c(id, registry, registration, title, completion_year, crossreg)) %>%
  ungroup()

render_0_multi_trial <- function(name, registries, completion_years, trials, name_for_file, survey_link, type, ...){

  if (!type %in% c("letter", "email")) stop("`type` must be 'letter' or 'email'")

  out_dir <- dir_create(path(dir_materials, glue("0_{type}")))
  out_file <- path(out_dir, name_for_file, ext = ifelse(type == "letter", "pdf", "md"))

  if (!file_exists(out_file)){
    rmarkdown::render(
      path(dir_templates, glue("0_{type}_multi.Rmd")),
      params = list(
        name = name,
        registries = registries,
        completion_years = completion_years,
        trials = trials,
        survey_link = survey_link
      ),
      output_file = out_file
    )
  }

  if (type == "email"){
    try(file_copy(path(dir_templates, "template.html"), path(out_dir, "template.html"), overwrite = FALSE), silent = TRUE)
  }
}

trialists_multi_trial %>%
  # slice_tail(n = test_n) %>%
  purrr::pwalk(render_0_multi_trial, survey_link = survey_link, type = "letter")

trialists_multi_trial %>%
  # slice_tail(n = test_n) %>%
  purrr::pwalk(render_0_multi_trial, survey_link = survey_link, type = "email")

# Check all letters created
letters <-
  dir_ls(path(dir_materials, "0_letter")) %>%
  path_file() %>%
  path_ext_remove()

all(letters %in% trialists$name_for_file)
all(trialists$name_for_file %in% letters)


# Prepare 1 (reminder,  cvk) ----------------------------------------------
rmarkdown::render(
  path(dir_templates, "1_email.Rmd"),
  output_dir = dir_create(path(dir_materials, "1_email")),
  output_file = "cvk"
)


# Prepare 2 (reminder) ----------------------------------------------------

render_reminder <- function(name, name_for_file, survey_link, n_reminder, ...){

  out_dir <- dir_create(path(dir_materials, glue("{n_reminder}_email")))

  rmarkdown::render(
    params = list(
      name = name,
      survey_link = survey_link
    ),
    input = path(dir_templates, glue("{n_reminder}_email.Rmd")),
    output_dir = out_dir,
    output_file = name_for_file
  )

  try(file_copy(path(dir_templates, "template.html"), path(out_dir, "template.html"), overwrite = FALSE), silent = TRUE)
}

# Based on survey/email feedback, some report cards corrected and receive different email
trials_corrected_report_card <- c(
  "DRKS00009368",
  "DRKS00009391",
  "DRKS00009539",
  "DRKS00012795",
  "DRKS00004649",
  "DRKS00003568",
  "NCT01984788" ,
  "NCT02509962",
  "NCT01266655"
) %>% str_c(collapse = "|")

# Corrected
trialists %>%
  filter(str_detect(ids, trials_corrected_report_card)) %>%
  purrr::pwalk(render_reminder, survey_link = survey_link, n_reminder = "2_corrected")

# Uncorrected
trialists %>%
  filter(str_detect(ids, trials_corrected_report_card, negate = TRUE)) %>%
  # slice_tail(n = test_n) %>%
  purrr::pwalk(render_reminder, survey_link = survey_link, n_reminder = 2)

# Note: Manually combined into "2_email" directory

# Prepare 3 (reminder) ----------------------------------------------------

trialists %>%
  # slice_tail(n = test_n) %>%
  purrr::pwalk(render_reminder, survey_link = survey_link, n_reminder = 3)

# Prepare 4 (reminder,  intervention only) --------------------------------

trialists %>%
  # slice_tail(n = test_n) %>%
  purrr::pwalk(render_reminder, survey_link = survey_link, n_reminder = 4)


# Convert to html and remove md -------------------------------------------
# send line to terminal: cmd+opt+enter
# cd communication-materials/materials
# cd 0_email
# find ./ -iname "*.md" -type f -exec sh -c 'pandoc --template=template.html "${0}" -o "${0%.md}.html"' {} \;
# cd ../2_email
# find ./ -iname "*.md" -type f -exec sh -c 'pandoc --template=template.html "${0}" -o "${0%.md}.html"' {} \;
# cd ../3_email
# find ./ -iname "*.md" -type f -exec sh -c 'pandoc --template=template.html "${0}" -o "${0%.md}.html"' {} \;
# cd ../4_email
# find ./ -iname "*.md" -type f -exec sh -c 'pandoc --template=template.html "${0}" -o "${0%.md}.html"' {} \;

dir_ls(dir_materials, regexp = "email") %>%
  dir_ls(regexp = ".md") %>%
  file_delete()


# Check all email created
emails <-
  dir_ls(path(dir_materials, "2_email"), regexp = "template", invert = TRUE) %>%
  path_file() %>%
  path_ext_remove()

all(emails %in% trialists$name_for_file)
all(trialists$name_for_file %in% emails)
