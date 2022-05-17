library(dplyr)
library(readr)
library(stringr)

data <- read_csv("data/processed/charite-contacts-per-trialist.csv")

email_parameters <- data %>%
  mutate(
    name_for_file = gsub("\\.", "", name),
    name_for_file = str_replace_all(name_for_file, "ä", "ae"),
    name_for_file = str_replace_all(name_for_file, "ö", "oe"),
    name_for_file = str_replace_all(name_for_file, "ü", "ue"),
    name_for_file = tolower(name_for_file),
    name_for_file = str_replace_all(name_for_file, " ", "-"),
    email_body_html = paste0("html/", name_for_file, ".html"),
    email_attachment = paste0("attach/", name_for_file, ".pdf"),
    subject_message = "Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  )

write_csv(email_parameters, "data/processed/email_parameters.csv")
