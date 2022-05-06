library(dplyr)
library(readr)
library(stringr)

data <- read_csv("data/processed/charite-contacts-per-trialist.csv")

email_parameters <- data %>%
  mutate(name_for_file = gsub("\\.", "", name)) %>%
  mutate(name_for_file = str_replace_all(name_for_file, "ä", "ae")) %>%
  mutate(name_for_file = str_replace_all(name_for_file, "ö", "oe")) %>%
  mutate(name_for_file = str_replace_all(name_for_file, "ü", "ue")) %>%
  mutate(name_for_file = tolower(name_for_file)) %>%
  mutate(name_for_file = str_replace_all(name_for_file, " ", "-")) %>%
  mutate(email_body_html = name_for_file) %>%
  mutate(email_body_html = paste0("html/", email_body_html, ".html")) %>%
  mutate(email_attachment = name_for_file) %>%
  mutate(email_attachment = paste0("attach/", email_attachment, "-materials.pdf"))

write_csv(email_parameters, "email_parameters.csv")
