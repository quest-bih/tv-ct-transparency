library(dplyr)
library(readr)
library(here)

data <- read_csv(here("data", "processed", "charite-contacts-per-trialist.csv"))

email_parameters <- data %>%

  mutate(
    launch_email_html = paste0("0_email/", name_for_file, ".html"),
    reminder_email_2_html = paste0("2_email/", name_for_file, ".html"),
    reminder_email_3_html = paste0("3_email/", name_for_file, ".html"),
    reminder_email_4_html = paste0("4_email/", name_for_file, ".html"),
    email_attachment = paste0("attach/", name_for_file, ".pdf"),
    subject_message = "Pilotstudie zur Transparenz Ihrer klinischen Studie(n)"
  )

write_csv(email_parameters, here("data", "processed", "email_parameters.csv"))
