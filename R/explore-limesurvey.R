# install.packages("limonaid")
library(limonaid) # limesurvey api
library(dplyr)
library(tidyr)

# LimeSurvey API documentation
# https://manual.limesurvey.org/RemoteControl_2_API
# https://api.limesurvey.org/classes/remotecontrol_handle.htm


# Get survey --------------------------------------------------------------

# Get stored limesurvey credentials if 1 and only 1 available, otherwise ask user
if (nrow(keyring::key_list("limesurvey")) == 1) {
  ls_username = keyring::key_list("limesurvey")$username
  ls_password = keyring::key_get("limesurvey", ls_username)
} else if (nrow(keyring::key_list("limesurvey")) == 0){
  ls_username = rstudioapi::askForPassword(prompt = "LimeSurvey Username:")
  ls_password = keyring::key_set("limesurvey", ls_username, prompt = "LimeSurvey Password:")
} else {
  ls_username = rstudioapi::askForPassword(prompt = "More than 1 LimeSurvey Username Found!\nSpecify Username:")
  ls_password = keyring::key_get("limesurvey", ls_username)
}

# Prepare limesurvey credentials
options(lime_api = "https://s-quest.bihealth.org/limesurvey/index.php/admin/remotecontrol")

# Start limesurvey api session
get_session_key(ls_username, ls_password)

# Get the survey id based on title
ls_id <-
  limer_call_limer(method = "list_surveys") %>%
  filter(surveyls_title == "Transparenz klinischer Studien an der Charité") %>%
  pull(sid)

ls_raw <- limer_get_responses(ls_id, sCompletionStatus = "all")


# Clean survey ------------------------------------------------------------

ls_clean <-
  ls_raw %>%

  janitor::clean_names() %>%

  # Change some column names
  rename(
    role_other_text = role_other_2,
    role_phd = role_ph_d
  ) %>%
  rename_with(~stringr::str_remove(., "rc_")) %>%
  rename_with(~stringr::str_remove(., "is_")) %>%

  # Recode NAs
  mutate(
    across(everything(), ~na_if(., "")),
    across(everything(), ~na_if(., "N/A"))
  ) %>%

  # `submitdate` available only if complete, and then same as `datestamp`
  mutate(completed = ifelse(!is.na(submitdate), TRUE, FALSE), .after = id) %>%

  # Remove unnecessary columns
  select(
    !contains("materials_usefulness"), # hidden item (not shown in survey)
    -submitdate, -startlanguage, -seed,
    -materials_display, -materials_reminder
  ) %>%

    # Recode true/false
    mutate(across(c(materials, correction, starts_with("role_")), ~if_else(. == "Ja", TRUE, FALSE, missing = NA))) %>%

  mutate(
    start = lubridate::ymd_hms(startdate),
    finish = lubridate::ymd_hms(datestamp),
    duration = finish-start,
    .keep = "unused",
    .after = "lastpage"
    )


# Check survey ------------------------------------------------------------

# Check whether >1 complete survey from same ip
ls_clean %>%
  filter(completed) %>%
  janitor::get_dupes(ipaddr)


# Prepare corrections -----------------------------------------------------

# Separate corrections since separate analysis
# For now, keep id
ls_corrections <-
  ls_clean %>%
  select(id, starts_with("correction_")) %>%

  # NOTE: current pipeline won't work if "more" corrections, so check
  assertr::assert(is.na, correction_text_more) %>%

  # Limit to rows with some data and remove empty columns
  filter(if_any(-id, ~!is.na(.))) %>%
  janitor::remove_empty("cols") %>%

  # Pivot to row per correction
  pivot_longer(-id,
               names_to = c("n_correction", "type"),
               names_prefix = "correction_text_trn",
               names_pattern = "(.)_correction_(.*)",
               values_to = "value"
  ) %>%
  mutate(value = stringr::str_trim(value)) %>%
  filter(!is.na(value)) %>%
  pivot_wider(names_from = "type", values_from = "value") %>%
  rename(correction = trn_text)

# Prepare survey ----------------------------------------------------------

ls <-
  ls_clean %>%

  # Remove corrections and ip
  select(-starts_with("correction_"), -ipaddr) %>% #colnames()

  # We keep incomplete responses as long mandatory likert complete
  filter(if_all(c(starts_with("reportcard"), starts_with("infosheet")), ~!is.na(.)))

readr::write_csv(ls, here::here("data", "processed", "limesurvey-clean.csv"))

# Get survey items --------------------------------------------------------

ls_items_raw <-
  limer_call_limer("list_questions", params = list(iSurveyID = ls_id))


# Clean survey items ------------------------------------------------------

ls_items <-
  ls_items_raw %>%
  select(qid, parent_qid, question_order, mandatory, type, title, question) %>%
  mutate(parent_qid = na_if(parent_qid, 0)) %>%
  mutate(across(c(qid, parent_qid, question_order), as.numeric)) %>%

  # Remove hidden item "MaterialsUsefulness"
  filter(qid != 55605) %>%
  filter(is.na(parent_qid) | parent_qid != 55605) %>%

  # Clean up titles to made survey dataframe
  mutate(title =
           janitor::make_clean_names(title) %>%

           stringr::str_replace(., "rc_", "reportcard_") %>%
           stringr::str_replace(., "is_", "infosheet_") %>%
           stringr::str_replace(., "ph_d", "phd") %>%
           stringr::str_replace(., "role_other", "role_other_text")

    ) %>%

  # Add "role_" to roles
  mutate(title = if_else(parent_qid == 55610, paste0("role_", title), title, missing = title)) %>%

  # Remove corrections "table" and other non-response items
  filter(is.na(parent_qid) | parent_qid != 55580) %>%
  filter(!title %in% c("materials_display", "materials_reminder", "correction_text_more")) %>%

  # Use question order for sub-items
  rename(subitem_order = question_order) %>%

  # Recode "role_other_text" as sub-item
  rows_update(
    tibble(title = "role_other_text", parent_qid = 55610, subitem_order = 7),
    by = "title"
  ) %>%

  # Items without parents are not sub-items
  mutate(subitem_order = if_else(is.na(parent_qid), NA_real_, subitem_order)) %>%

  # Add item order
  mutate(
    item_order = case_when(
      title == "materials" ~ 1,
      title == "correction" ~ 2,
      title == "correction_text" ~ 3,
      stringr::str_detect(title, "^reportcard")~ 4,
      stringr::str_detect(title, "^infosheet") ~ 5,
      title == "changes" ~ 6,
      stringr::str_detect(title, "^role") ~ 7,
      title == "comments" ~ 8
    ),
    .before = subitem_order
  ) %>%

  # Remove html from question text
  mutate(
    question = stringr::str_remove_all(question,  "<.*?>"),
    question = stringr::str_remove_all(question, "\r\n$"),
    question = stringr::str_replace(question, "\r\n\r\n", " ")
  ) %>%

  arrange(item_order, subitem_order)

# TODO
# "spread" mandatory
# add consent
# clarify type
# remove non-questions?

# Explore survey ----------------------------------------------------------

# How many "complete" (i.e. with likert) survey responses?
nrow(ls)

# Explore dates
date_launch <- lubridate::ymd("2022-05-25")
date_reminder_1 <- lubridate::ymd("2022-06-03") #cvk
date_reminder_2 <- lubridate::ymd("2022-06-29")

# Check that none before launch
filter(ls, start < date_launch)

# How many before reminder 1?
n_launch <-
  ls %>%
  filter(start >= date_launch & start < date_reminder_1) %>%
  nrow()

# How many after reminder 1 and before reminder 2?
n_reminder_1 <-
  ls %>%
  filter(start >= date_reminder_1 & start < date_reminder_2) %>%
  nrow()

n_reminder_2 <-
  ls %>%
  filter(start >= date_reminder_2) %>%
  nrow()

# How many self-report looking at materials before survey?
n_no_materials <- ls %>% filter(!materials) %>% nrow()

# How many have corrections?
# Limit to those with correction content, not just self-regport
n_complete_corrections <-
  ls %>%
  semi_join(ls_corrections, by = "id") %>%
  filter(correction) %>%
  nrow()

# Look at changes and comments
changes_comments <-
  ls %>%
  filter(!is.na(changes) | !is.na(comments)) %>%
  select(changes, comments) %>%
  pivot_longer(everything(), names_to = "type", values_to = "text") %>%
  mutate(text = if_else(text %in% c("-", "nein", "Nein.", "Keine"), NA_character_, text)) %>%
  drop_na(text)


# Explore survey: roles ---------------------------------------------------

ls %>%
  select(id, starts_with("role") & !ends_with("text")) %>%
  count(across(starts_with("role"))) %>%
  arrange(desc(n))

library(ggplot2)
plot_roles <-
  ls %>%
  select(id, starts_with("role") & !ends_with("text")) %>%
  pivot_longer(cols = -id, names_to = "role") %>%
  filter(value == TRUE) %>%
  mutate(
    role = stringr::str_remove(role, "role_"),
    role = stringr::str_to_sentence(role)
  ) %>%
  group_by(id) %>%
  mutate(roles = list(role)) %>%
  ungroup() %>%
  distinct(id, roles) %>%
  ggplot(aes(x = roles)) +
  geom_bar() +
  geom_text(
    stat = 'count',
    aes(label = scales::percent(after_stat(count)/nrow(ls), accuracy = 1)),
    vjust = -.5,
    size = 3.5) +
  ggupset::scale_x_upset() +
  ylab("Number of survey respondents") +
  xlab(NULL) +
  ggupset::theme_combmatrix(
    # combmatrix.label.make_space = FALSE,
    combmatrix.panel.line.size = 0,
    combmatrix.label.text = element_text(
      # family = "Roboto",
      size = 11)
  )


# Explore survey: likert --------------------------------------------------

likert_levels <- tibble(
  level = c(
    "trifft zu",
    "trifft eher zu",
    "teils-teils",
    "trifft eher nicht zu",
    "trifft nicht zu"
  ),
  value = 5:1
)

# Get row per likert item level with count
likert_data <-
  ls %>%
  select(starts_with("reportcard"), starts_with("infosheet")) %>%
  pivot_longer(everything(), names_to = "item", values_to = "level") %>%
  group_by(item, level) %>%
  summarise(n = n(), .groups = "drop")

# Get proportion of levels for each likert
likert_prop <-
  likert_data %>%
  mutate(prop = n/nrow(ls) * 100) %>%
  arrange(item, level) %>%
  select(-n) %>%
  pivot_wider(id_cols = item,
              names_from = level,
              values_from = prop
  )

# Get mean for each likert
likert_mean <-
  likert_data %>%
  left_join(likert_levels, by = "level") %>%
  mutate(level_value = n*value) %>%
  group_by(item) %>%
  summarise(mean = sum(level_value)/nrow(ls))

# Combine likert summary info
likert_summary <-
  likert_prop %>%

  left_join(likert_mean, by = "item") %>%

  # Add question text
  left_join(select(ls_items, title, question), by = c("item" = "title")) %>%
  select(item, question, mean, likert_levels$level)

# Prepare likert display
likert_display <-
  likert_summary %>%
  gt::gt() %>%
  gt::fmt_percent(
    columns = -c(item, question, mean),
    scale_values = FALSE,
    decimals = 0
  ) %>%
  gt::tab_header(title = "Usefulness of Report Card and Infosheet") %>%
  gt::tab_footnote('Mean calculated with scale from "trifft zu" = 5 to "trifft nicht zu" = 1')
