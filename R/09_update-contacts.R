library(dplyr)
library(tidyr)
library(here)
library(readr)
library(stringr)

contacts <- read_csv(here("data", "processed", "charite-contacts.csv"))
email_info <- read_csv(here("data", "processed", "email-delivery-info.csv"))

undeliverable_emails <-
  email_info %>%
  filter(!delivered) %>%
  pull(email) %>%
  paste(collapse = "|")

contacts_with_undeliverable <-
  contacts %>%
  mutate(
    email_delivered =
      str_remove_all(email, undeliverable_emails) %>%
      str_remove(., "^;|; $") %>% str_squish(.) %>% na_if(., ""),
    trial_email_delivered =
      str_remove_all(trial_email, undeliverable_emails) %>%
      str_remove(., "^;|; $") %>% str_squish(.) %>% na_if(., ""),
    excluded = if_else(is.na(email_delivered), TRUE, FALSE)
  )

all_contacts <-
  contacts_with_undeliverable %>%
  distinct(name)

all_trials <-
  contacts_with_undeliverable %>%
  distinct(id)

included_contacts <-
  contacts_with_undeliverable %>%
  filter(!excluded) %>%
  distinct(name)

included_trials <-
  contacts_with_undeliverable %>%
  filter(!excluded) %>%
  distinct(id)

excluded_contacts <-
  contacts_with_undeliverable %>%
  filter(excluded) %>%
  distinct(name)
