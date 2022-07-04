library(dplyr)
library(tidyr)
library(here)
library(readr)
library(stringr)


# Prepare all contacts and emails -----------------------------------------

contacts <- read_csv(here("data", "processed", "charite-contacts.csv"))

# Get all emails for all charite contacts
all_emails <-
  contacts %>%
  select(email, trial_email) %>%
  separate_rows(c(email, trial_email), sep = "; ") %>%
  rename(trialist = email, trial = trial_email) %>%
  pivot_longer(everything(),
               names_to = "email_type", values_to = "email",
               values_drop_na = TRUE
  ) %>%
  distinct(email, .keep_all = TRUE) %>%
  arrange(email_type)

# Get last name for each email
contacts_last <-
  contacts %>%
  select(name, email) %>%
  mutate(last = stringr::str_extract(name, "[-\\w]*$"), .after = name) %>%
  distinct(last, email)

# Prepare email logs ------------------------------------------------------

# Number of email indicates launch/reminders
# NOTE: Change this to check different logs
n_email <- 2

# Specificy subject and sender based on number
if (n_email == 0){
  email_subject <- "Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  email_sender <- "quest-trackvalue"
} else if (n_email == 1){
  email_subject <- "Erinnerung: Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  email_sender <- "christof.kalle"
} else if (n_email == 2){
  email_subject <- "Erinnerung: Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  email_sender <- "quest-trackvalue"
}

email_log_path <- here("data", "raw", "emails", paste0(n_email, "_email.txt"))

email_log_raw <-
  read_delim(email_log_path, col_names = "value", delim = "\n", locale = locale(encoding = "latin1"))

# Clean email log
email_log <-
  email_log_raw %>%
  separate(
    value, into = c("type", "text"), sep = ":\t",
    extra = "merge", fill = "right"
  ) %>%
  filter(type %in% c("Von", "Gesendet", "An", "Betreff")) %>%
  group_by(type) %>%
  mutate(n = row_number()) %>%
  ungroup() %>%
  pivot_wider(id_cols = n, names_from = type, values_from = text) %>%
  select(-n) %>%
  rename(
    from = Von,
    date = Gesendet,
    to = An,
    subject = Betreff
  )


# Check sent emails -------------------------------------------------------

email_sent <-
  email_log %>%

  # Emails sent with specified subject and from
  filter(
    subject == email_subject &
      str_detect(from, email_sender)
  ) %>%

  # Some "to" are emails and others are names, so clean to emails only
  mutate(
    email = if_else(str_detect(to, "@"), to, NA_character_),
    name = if_else(str_detect(to, ","), to, NA_character_)
  ) %>%
  separate("name", into = c("last", "first"), sep = ", ") %>%

  # Manually fix some trialist names
  mutate(last = case_when(
    last == "Preißner" ~ "Preissner",
    last == "Thuß" ~ "Thuss-Patience",
    last == "Röpke" ~ "Roepke",
    last == "von Stackelberg" ~ "Stackelberg",
    str_detect(last, "sehouli") ~ "Sehouli",
    TRUE ~ last
  )) %>%
  mutate(email = if_else(str_detect(email, "sehouli"), NA_character_, email)) %>%
  left_join(contacts_last, by = "last") %>%
  mutate(email = coalesce(email.x, email.y)) %>%
  select(from, date, to = email, subject)

sent_emails <-
  email_sent %>%
  separate_rows(to, sep = "; ") %>%
  pull(to)


# Check issue emails ------------------------------------------------------

email_issues <-
  email_log %>%

  # Emails with issues with any other subject or from
  filter(
    subject != email_subject |
      str_detect(from, email_sender, negate = TRUE)
  )

# Check that all emails either sent or issue
if(nrow(email_sent) + nrow(email_issues) != nrow(email_log)) {
  message("Not all emails in log either sent or issue!")
}

# From email 1 (launch), most (n = 43) emails issues "undeliverable" with some (n = 4) auto replies
# From email 2 (reminder), most (n = 44) emails issues "undeliverable" with some (n = 2) auto replies
count(email_issues, subject)


# Check undeliverable emails ----------------------------------------------

email_undeliverable <-
  email_issues %>%
  filter(subject == paste0("Undeliverable: ", email_subject)) %>%

  # "to" should be email address
  mutate(to = case_when(
    to == "Megow, Inna" ~ "inna.megow@charite.de",
    to == "Vlatsas, Stergios" ~ "stergios.vlatsas@charite.de",
    TRUE ~ to
  ))

# Check that all email_undeliverable "to" are email addresses
if (nrow(filter(email_undeliverable, str_detect(to, "@", negate = TRUE)))){
  message('`email_undeliverable` "to" should be email!')
}

# Check that all email_undeliverable in email_parameters
anti_join(email_undeliverable, all_emails, by = c("to" = "email"))


# Check auto-reply emails -------------------------------------------------
# TODO: decide how to handle these

email_auto_reply <-
  email_issues %>%
  filter(subject != paste0("Undeliverable: ", email_subject))

# Gather email info -------------------------------------------------------

email_info <-
  all_emails %>%
  mutate(
    sent =
      if_else(email %in% sent_emails, TRUE, FALSE) %>%
      if_else(email_type == "trial", NA, .),
    delivered = case_when(
      n_email == 1 ~ NA, # undeliverable notices sent to cvk so unknown
      email %in% email_undeliverable$to ~ FALSE,
      TRUE ~ TRUE
    )
  )



# Explore emails ----------------------------------------------------------

email_info %>%
  count(email_type, sent, delivered)

# Check if any trialist email not sent
unsent_email <-
  email_info %>%
  filter(email_type == "trialist", !sent)

if (nrow(unsent_email > 0)){
  message(paste("Unsent email:", unsent_email$email))
}

# 2022-06-16: We noticed Robert Armbrust did not receive emails since the email is incorrect in DRKS (https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID=DRKS00007117): robert.armbrust@charite,de --> we will manually send email. also add an assertion that no commas in emails

delivered_emails <-
  email_info %>%
  filter(sent & delivered)


# Save email info ---------------------------------------------------------

# Add email number
email_delivery_info <-
  email_info %>%
  rename_with(~ paste0(n_email, "_", .), c(sent, delivered))

# Check if previously saved email delivery info and, if so, read in (and append)
email_delivery_info_path <- here("data", "processed", "email-delivery-info.csv")

if (fs::file_exists(email_delivery_info_path)) {

  email_delivery_info <-
    read_csv(email_delivery_info_path) %>%

    # If same columns in old and new, remove old
    select(-(intersect(colnames(email_delivery_info), colnames(.))), email_type, email) %>%
    # rename_with(~ paste0(n_email, "_", .), c(sent, delivered)) %>%
    # select(-colnames(email_delivery_info), email_type, email) %>%

    full_join(email_delivery_info, ., by = c("email_type", "email"))
}

write_csv(email_delivery_info, here("data", "processed", "email-delivery-info.csv"))
