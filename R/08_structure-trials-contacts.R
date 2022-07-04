# Restructure trackvalue charite contacts into:
# contacts: row per trial, per trialist
# contacts_per_trial: row per trial (with all trialists)
# contacts_per_trialist: row per trialist (with all trials)
# email_parameters: `contacts_per_trialist` with additional email params

library(dplyr)
library(here)
library(readr)
library(stringr)

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

contacts <- read_csv(here("data", "processed", "charite-contacts.csv"))

# Contacts per trial ------------------------------------------------------

contacts_per_trial <-
  contacts %>%

  group_by(id) %>%

  # How many contacts?
  add_count(name = "n_contacts") %>%

  # Which contacts?
  mutate(contacts = paste_rows(name)) %>%

  ungroup() %>%
  distinct(id, registry, n_contacts, contacts) %>%
  arrange(desc(n_contacts))

# How many trials with each number of contacts per registry?
contacts_per_trial %>%
  count(registry, n_contacts, name = "n_trials")

# For example, which contacts for trial with most contacts?
contacts_per_trial %>%
  slice_head(n = 1) %>%
  semi_join(contacts, ., by = "id") %>%
  select(name, contact_type, title, position)

write_csv(contacts_per_trial, here("data", "processed", "charite-contacts-per-trial.csv"))


# Trials per contact ------------------------------------------------------

contacts_per_trialist <-
  contacts %>%

  group_by(name) %>%

  # How many trials?
  add_count(name = "n_trials") %>%

  # Which trials?
  mutate(ids = paste_rows(id)) %>%

  ungroup() %>%

  distinct(name, n_trials, ids, email, trial_email, title) %>%

  # Two trialists appear twice because of trials emails, so collapse
  group_by(name) %>%
  mutate(trial_email = paste_rows(trial_email)) %>%
  ungroup() %>%
  distinct() %>%

  arrange(desc(n_trials)) %>%

  # Create filename from trialist name
  mutate(name_for_file =
           name %>%
           str_remove_all(., "\\." ) %>%
           str_replace_all(., "ä", "ae") %>%
           str_replace_all(., "ö", "oe") %>%
           str_replace_all(., "ü", "ue") %>%
           str_to_lower(.) %>%
           str_replace_all(" ", "-")
  )


# How many contacts with each number of trials per registry?
contacts_per_trialist %>%
  count(n_trials, name = "n_contacts")

# For example, which trials for contact with most trials?
contacts_per_trialist %>%
  slice_head(n = 1) %>%
  semi_join(contacts, ., by = "name") %>%
  select(name, registry, id)

write_csv(contacts_per_trialist, here("data", "processed", "charite-contacts-per-trialist.csv"))


# Email parameters --------------------------------------------------------

email_parameters <-

  contacts_per_trialist %>%

  mutate(
    launch_email_html = paste0("0_email/", name_for_file, ".html"),
    reminder_email_2_html = paste0("2_email/", name_for_file, ".html"),
    reminder_email_3_html = paste0("3_email/", name_for_file, ".html"),
    reminder_email_4_html = paste0("4_email/", name_for_file, ".html"),
    email_attachment = paste0("attach/", name_for_file, ".pdf"),
    subject_message = "Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  )

write_csv(email_parameters, here("data", "processed", "email_parameters.csv"))

