# Prepare contact based on AACT (for all IntoValue) plus ClinicaTrials.gov and DRKS historical versions

library(dplyr)
library(tidyr)
library(stringr)
library(here)
library(readr)
library(fs)
library(jsonlite)
library(cthist) # historical registry data

queries_log_path <- file_create(here("data", "queries.log"))

# Get data ----------------------------------------------------------------

trackvalue <-
  read_csv(here("data", "processed", "trackvalue.csv"))

# Get ctgov historical versions
ctgov_trns <-
  trackvalue %>%
  filter(registry == "ClinicalTrials.gov") %>%
  select(id) %>%
  pull()

h_ctgov_file <- here("data", "raw", "historical-ctgov.csv")

if (!file_exists(h_ctgov_file)) {
  message("Downloading ClinicalTrials.gov")
  clinicaltrials_gov_download(ctgov_trns, h_ctgov_file)

  loggit::set_logfile(queries_log_path)
  loggit::loggit("INFO", "Historical CTGOV")
} else {message("ClinicalTrials.gov already downloaded")}

h_ctgov <-
  read_csv(h_ctgov_file) %>%
  rename(id = nctid)

# Get drks historical versions
drks_trns <-
  trackvalue %>%
  filter(registry == "DRKS") %>%
  select(id) %>%
  pull()

h_drks_file <- here("data", "raw", "historical-drks.csv")

if (!file_exists(h_drks_file)) {
  message("Downloading DRKS")
  drks_de_download(drks_trns, h_drks_file)

  loggit::set_logfile(queries_log_path)
  loggit::loggit("INFO", "Historical DRKS")
} else {message("DRKS already downloaded")}

h_drks <-
  read_csv(h_drks_file) %>%
  rename(id = drksid)


# Prepare historical ctgov ------------------------------------------------

# Extract contents from json column and keep unique from latest version
# Return dataframe with id, version, and json (label and contents)
extract_unique_json <- function(df, var) {
  df %>%
    select(id, version_number, {{var}}) %>%
    arrange(id) %>%

    # Extract contacts from json
    mutate(json_col = purrr::map({{var}}, ~ fromJSON(.) %>% as.data.frame())) %>%
    select(-{{var}}) %>%
    tidyr::unnest(json_col) %>%

    # Remove rows with no content
    mutate(content = na_if(content, "")) %>%
    drop_na(content) %>%

    # Keep each unique contact, with latest version number
    group_by(id) %>%
    arrange(desc(version_number)) %>%
    ungroup() %>%
    distinct(id, label, content, .keep_all = TRUE) %>%

    # Remove trailing semicolon on label
    mutate(label = str_remove(label, ":$"))

}

# Prepare contacts
h_ctgov_contacts <-
  h_ctgov %>%

  # Extract unique contacts from json
  extract_unique_json(contacts) %>%

  # Use \n to break off name
  # Additional pieces go in organization; if only one piece, name
  separate(content, c("name", "organization"), sep = "\n", extra = "merge", fill = "right") %>%

  # Extract email and phone
  mutate(
    email = str_extract(organization, "Email: .+$"),
    organization = str_remove(organization, "Email: .+$"),
    email = str_remove(email, "Email: "),

    phone = str_extract(organization, "Telephone: .+$"),
    organization = str_remove(organization, "Telephone: .+$"),
    phone = str_remove(phone, "Telephone: ")
  ) %>%

  # Clean contact types
  rename(contact_type = label) %>%
  mutate(
    # contact_type = str_remove(label, ":$"),
    contact_type = case_when(
      contact_type == "Central Contact Person" ~ "central_primary",
      contact_type == "Central Contact Backup" ~ "central_backup",
      contact_type == "Study Officials" ~ "study_official"
    )#,
    # .keep = "unused"
  ) %>%

  # Make empty strings or \n into NA
  mutate(
    organization = na_if(organization, ""),
    organization = na_if(organization, "\n")
  ) %>%

  # Use \n to break off position from organization
  separate(organization, c("position", "organization"), sep = "\n") %>%

  # Move remaining email in organization (i.e., NCT02314572)
  mutate(
    email = if_else(
      str_detect(organization, "\\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+\\b"),
      str_extract(organization, "\\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+\\b"),
      email, missing = email
    ),

    organization = if_else(
      str_detect(organization, "\\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+\\b"),
      str_remove(organization, "\\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+\\b"),
      organization
    ),

    organization = na_if(organization, "")
  ) %>%

  # Correct trials with organization in name
  mutate(
    organization = if_else(name %in% c("Novartis Pharmaceuticals", "Medtronic Clinical Studies", "Galderma", "Glycotope GmbH"), name, organization),
    name = if_else(name %in% c("Novartis Pharmaceuticals", "Medtronic Clinical Studies", "Galderma", "Glycotope GmbH"), NA_character_, name)
  ) %>%
  # Use \n to split name and title(s)
  # Additional pieces go in title; if only one piece, name
  separate(name, c("name", "title"), sep = ", ", extra = "merge", fill = "right") %>%

  # Tidy titles
  mutate(

    # Replace periods between words with space and remove other periods
    title = str_replace_all(title, "(?<=\\w)\\.(?=\\w)", " "),
    title = str_remove_all(title, "\\."),

    # Add space after comma
    title = str_replace_all(title, ",(?=\\w)", ", "),

    # Fix some typos
    title = str_replace(title, "M D", "MD"),
    title = str_replace(title, "MD (?=\\w)", "MD, "),
    title = str_replace(title, "(?<=\\w) MD", ", MD"),
    title = str_replace(title, "M [S|s]c", "MSc"),
    title = str_replace(title, "Doctor", "Dr"),
    title = str_replace(title, "Prof{1,2}es{1,2}or", "Prof"),
    title = str_replace(title, "Dipl Psych", "Dipl-Psych"),

    # Change comma to semicolon
    title = str_replace_all(title, ",", ";")
  ) %>%

  # Correct incorrect email/name pair
  mutate(email = if_else(name == "Agnieszka Korfel", "agnieszka.korfel@charite.de", email, missing = email))

# Get known ctgov titles
titles <-
  h_ctgov_contacts %>%
  distinct(title) %>%
  drop_na() %>%
  add_row(title = "Prof Dr Dr") %>%  # Add some titles
  pull() %>%
  str_split("; ") %>%
  unlist() %>%
  unique() %>%
  .[order(desc(nchar(.)), .)] %>%  # Arrange by descending title length (so that longer titles checked first)
  str_c(collapse = "|")

# Prepare sponsors/responsible parties
# Responsible party may be "Sponsor", "Principal Investigator", or "Sponsor-Investigator"
# https://ictr.johnshopkins.edu/programs_resources/programs-resources/clinicaltrials-gov-program/who-is-responsible/
# https://clinicaltrials.gov/ct2/manage-recs/faq#responsibleParty
h_ctgov_sponsor_collaborators <-
  h_ctgov %>%

  # Extract unique contacts from json
  extract_unique_json(sponsor_collaborators) %>%

  rename(contact_type = label, organization = content) %>%

  mutate(contact_type = snakecase::to_snake_case(contact_type))

# Prepare contacts when responsible party is "Principal Investigator" or "Sponsor-Investigator"
h_ctgov_investigators <-
  h_ctgov_sponsor_collaborators %>%

  # Limit to investigators
  filter(str_detect(organization, "Investigator") & contact_type == "responsible_party") %>%

  # Use \n to separate organization into components, then tidy
  separate(organization, c("position", "name", "blank", "official_title", "organization"), sep = "\n", extra = "merge") %>%
  select(-blank) %>%
  mutate(across(c(everything(), -version_number), ~ str_remove(., "^.+: "))) %>%

  # Tidy names and official titles to prepare for extracting titles
  mutate(across(c(name, official_title),
                ~ str_replace_all(., "\\.", " ") %>%
                  str_squish() %>%
                  # str_remove_all(., "\\.") %>%
                  str_remove_all("(?<=-)\\s|\\s(?=-)") %>% # spaces around dashes
                  str_replace_all("Professor", "Prof") %>%
                  str_replace_all("M D", "MD") %>%
                  str_replace_all("Dipl Psych", "Dipl-Psych")

  )) %>%

  # Extract all titles from name and official title and collapse to unique
  mutate(
    title_1 = str_extract_all(name, titles),
    title_2 = str_extract_all(official_title, titles)
  ) %>%
  rowwise() %>%
  mutate(title =
           str_c(title_1, title_2, sep = "; ", collapse = "; ") %>%
           str_split("; ") %>%
           unlist() %>%
           unique() %>%
           str_c(collapse = "; ") %>%
           na_if("")
  ) %>%
  ungroup() %>%
  select(-title_1, -title_2) %>%

  # Remove titles from name and official title, and tidy
  mutate(across(c(name, official_title),
                ~ str_remove_all(., titles) %>%
                  str_remove_all("^[,;\\s]+|[,;\\s]+$") %>%  # comma/semicolon at start/end
                  str_trim()
  )) %>%

  # Manually clean up some names
  mutate(across(c(name, official_title), ~ str_replace_all(., "Agnes Floe{1,2}l", "Agnes Flöel"))) %>%
  mutate(name = if_else(name =="JSehouli", "Jalid Sehouli", name)) %>%

  # Remove name from official title, and tidy
  mutate(official_title =
           str_remove(official_title, name) %>%
           str_remove_all("^[,;\\s]+|[,;\\s]+$") %>%
           str_trim()
  ) %>%

  # Manually clean up some official titles
  mutate(official_title =

           # PI already indicated under "position"
           str_remove(official_title, "PI|Princip[a]?l[e]? Investigator") %>%

           # Remnants otherwise captured with "title"
           str_remove("Univ\\b|^of |Ern-wiss") %>%

           # Name not exact match so not removed before
           str_remove("- M Sander") %>%

           # Remove other names which are errors on ctgov
           # NCT01181401: Carmen Stromberger/Volker Budach
           # NCT00942747: Philipp Kiewe/Agnieszka Korfel
           str_remove("Volker Budach|Agnieszka Korfel") %>%

           na_if("")
  ) %>%

  # Add official title to organization
  unite(organization, official_title, organization, sep = ", ", na.rm = TRUE)

h_ctgov_sponsors <-

  # Prepare contacts when responsible party is "Sponsor"
  h_ctgov_sponsor_collaborators %>%

  # Limit to investigators
  filter(organization == "Sponsor" | contact_type == "sponsor") %>%
  arrange(id) %>%

  # Prepare organizations to remove "Sponsor-Investigator"
  mutate(organization =
           str_remove_all(organization, "(?<!Co|Ltd)\\.") %>% # remove periods (non-corporate)
           str_remove_all(titles) %>% # remove titles
           str_remove_all("^[,;\\s]+|[,;\\s]+$") %>% # comma/semicolon at start/end
           str_squish() %>%
           str_replace("JSehouli", "Jalid Sehouli")
  ) %>%

  # Remove sponsors already captured as "Sponsor-Investigator"
  anti_join(
    filter(h_ctgov_investigators, position == "Sponsor-Investigator"),
    by = c("id", "organization" = "name")
  ) %>%

  # NCT01541579 has different sponsors at different versions
  # Tigenix is a later version and acquired Cellerix
  filter(!(id == "NCT01541579" & organization == "Cellerix")) %>%

  # Pivot to row per trial with `sponsor` and `responsible_party`
  pivot_wider(c(id, version_number),
              names_from = contact_type,
              values_from = organization
  ) %>%

  # If `responsible_party` is "Sponsor", copy `sponsor`
  mutate(responsible_party = if_else(responsible_party == "Sponsor", sponsor, responsible_party)) %>%

  # Pivot to row per contact
  pivot_longer(c(sponsor, responsible_party),
               names_to = "contact_type",
               values_to = "organization",
               values_drop_na = TRUE) %>%

  # Add `position` for "responsible_party"
  mutate(position = if_else(contact_type == "responsible_party", "Sponsor", NA_character_))

# Combine contacts and sponsors
h_ctgov_contact_info <-
  bind_rows(h_ctgov_contacts, h_ctgov_investigators, h_ctgov_sponsors) %>%
  arrange(id, version_number) %>%

  mutate(registry = "ClinicalTrials.gov", .after = id) %>%

  # Version number not needed
  select(-version_number)

# Prepare historical drks -------------------------------------------------

h_drks_contact_info <-
  h_drks %>%
  select(id, version_number, contacts) %>%

  # Extract contacts from json
  mutate(contacts = purrr::map(contacts, ~ fromJSON(.) %>% as.data.frame())) %>%
  tidyr::unnest(contacts) %>%

  # Drop empty rows and columns
  # Presumable data entry error DRKS00009539 and DRKS00009391 (with "Additional Inclusion Criteria", so irrelevant) seems to have created additional rows and columns
  drop_na(label) %>%
  janitor::remove_empty("cols") %>%

  # Keep each unique contact, with latest version number
  group_by(id) %>%
  arrange(desc(version_number)) %>%
  ungroup() %>%
  distinct(across(-version_number), .keep_all = TRUE) %>%

  # Make [---]* and empty string NA
  mutate(across(everything(), ~ na_if(., "[---]*"))) %>%
  mutate(across(everything(), ~ na_if(., ""))) %>%

  # Convert "at" to proper email @
  mutate(
    email = str_replace(email, " at ", "@"),
    email = tolower(email)
  ) %>%

  # Use space and last period to split name and title(s)
  # Additional pieces go in name; if only one piece, name
  separate(name, c("title", "name"), sep = " (?!.*\\.)", extra = "merge") %>%

  # Use first space to split personal title
  separate(title, c("personal_title", "title"), sep = " ", extra = "merge", fill = "right") %>%

  # Tidy titles
  mutate(
    personal_title = str_remove_all(personal_title, "\\."),
    title = str_remove_all(title, "\\."),
    title = str_replace(title, "Professor", "Prof")
  ) %>%

  rename(
    contact_type = label,
    organization = affiliation,
    phone = telephone
  ) %>%

  mutate(contact_type = snakecase::to_snake_case(contact_type)) %>%

  # Remove collaborators
  filter(contact_type != "collaborator_other_address") %>%

  mutate(registry = "DRKS", .after = id) %>%

  # Version number not needed
  select(-version_number)


# Combine ctgov and drks contacts -----------------------------------------

tv_contacts <-
  bind_rows(h_ctgov_contact_info, h_drks_contact_info) %>%

  # Change semicolon to comma
  mutate(organization = str_replace_all(organization, ";", ",")) %>%

  # Make all emails lowercase
  mutate(email = tolower(email)) %>%

  # Unify Charité spelling
  mutate(organization = str_replace_all(organization, "(?<=[cC])harit[eè]", "harité")) %>%

  # Make names to titlecase
  mutate(name = str_to_title(name)) %>%

  # Append period to initials in names
  mutate(name = str_replace_all(name, "(?<=\\s|^)([A-Z]{1})\\s", "\\1. ")) %>%

  # Manually clean up some names
  mutate(across(c(name, organization), ~ str_replace_all(., "Jalid Sehouli Sehouli|JSehouli", "Jalid Sehouli"))) %>%

  mutate(name = case_when(
    name == "Anika" & id == "DRKS00012665" ~ "Anika Steinert",
    str_detect(name, "Christian [SH]. Kessler") ~ "Christian Kessler",
    str_detect(name, "Thuss-Patience") ~ "Peter C. Thuss-Patience",
    name %in% c("Claudia D. Spies", "Spies Claudia") ~ "Claudia Spies",
    name == "Agnes Floeel" ~ "Agnes Flöel",
    name == "Anja Maehler" ~ "Anja Mähler",
    name == "Ingo Fietz" ~ "Ingo Fietze",
    name == "Maurer (Ici) Marcus" ~ "Maurer Marcus",
    name == "Susanne Wiegand" ~ "Susanna Wiegand",
    name == "Thomas D. Halbig" ~ "Thomas D. Hälbig",
    name == "Ralf Trappe" ~ "Ralf U. Trappe",
    name == "Moritz Petzold" ~ "Moritz B. Petzold",
    name == "Andres Neuhaus" ~ "Andres H. Neuhaus",
    name == "C. Storm" ~ "Christian Storm",
    name == "Johannes Lauscher" ~ "Johannes C. Lauscher",
    name == "Jurgen Birnbaum" ~ "Jürgen Birnbaum",
    name == "K. Weller" ~ "Karsten Weller",
    name == "Andreas A. Michalsen" ~ "Andreas Michalsen",
    name == "David Manuel Leistner" ~ "David M. Leistner",
    name == "Markus Schuelke" ~ "Markus Schülke-Gerstenfeld",
    TRUE ~ name
  )) %>%

  # Manually correct some emails
  # We found some emails associated with multiple names and so correct clearly incorrect email/name pairs
  # All emails found via web search using publicly available data
  mutate(email = case_when(
    name == "Thomas Reinehr" ~ "t.reinehr@kinderklinik-datteln.de",
    name == "Wieland Kiess" ~"wieland.kiess@medizin.uni-leipzig.de",
    TRUE ~ email
  )) %>%

  # Some trials have a generic trial email. Move to a new column.
  mutate(

    # Add trial email to all trial contacts
    trial_email = case_when(
      id == "NCT01143233" ~ "kinder-allergiestudien@charite.de",
      id == "NCT00865982" ~ "magenkarzinom@charite.de",
      id == "NCT01503372" ~ "magenkarzinom@charite.de",
      id == "NCT01370044" ~ "ncrc@charite.de",
      id == "DRKS00004871" ~ "studien.naturheilkunde@immanuel.de; naturheilkunde@immanuel.de",

      # No email found for Annika Bickenbach, so keep only charite contact
      # id == "DRKS00004195" ~ "babeluga@charite.de",
      TRUE ~ NA_character_
    ),

    # Remove only trial email only from email
    email = case_when(
      id == "NCT01143233" & email == "kinder-allergiestudien@charite.de" ~
        NA_character_,
      id == "NCT00865982" & email == "magenkarzinom@charite.de" ~
        NA_character_,
      id == "NCT01503372" & email == "magenkarzinom@charite.de" ~
        NA_character_,
      id == "NCT01370044" & email == "ncrc@charite.de" ~
        NA_character_,
      id == "DRKS00004871" & email %in% c("studien.naturheilkunde@immanuel.de", "naturheilkunde@immanuel.de") ~
        NA_character_,
      # No email found for Annika Bickenbach, so keep only charite contact
      # id == "DRKS00004195" & trial_email == "babeluga@charite.de" ~
      #   NA_character_,
      TRUE ~ email
    )
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

tv_contacts_unique <-
  tv_contacts %>%

  # If email/title associated with name somewhere, spread to other instances of name (from same and other trials, e.g., "Gerbitz|Flöel|Sehouli")
  # Some contacts without name have email but should not be spread to all contacts without name
  group_by(name) %>%
  mutate(
    email = if_else(!is.na(name), paste_rows(email), email),
    title = paste_rows(title)
  ) %>%
  ungroup() %>%

  # Collapse same name for same trial
  group_by(id, name) %>%
  summarise(across(everything(), paste_rows)) %>%
  ungroup()

# Limit to charite contacts -----------------------------------------------

# Expect charite or berlin in name, email, or organization
tv_charite_contacts <-
  tv_contacts_unique %>%

  # Expect charite or berlin in name, email, or organization
  filter(if_any(c(name, email, organization, trial_email), ~ str_detect(., "(?i)charit|berlin"))) %>%

  # Remove contacts with no name (i.e., organizations)
  drop_na(name)

# Visually inspect excluded contacts
tv_non_charite_contacts <- anti_join(tv_contacts_unique, tv_charite_contacts)


# Handle missing Charité emails -------------------------------------------
# For charite contacts missing emails, we try to find an email through (1) charite email global address lists, and (2) online searches (name, charite, medical field informed by trial registration). For online searches, capture source in  `email_source`
# Many thanks for Nicole Hildebrand for email sleuthing!

charite_contacts_missing_email <-
  tv_charite_contacts %>%
  filter(is.na(email)) %>%
  group_by(name) %>%
  add_count(name = "n_trials") %>%
  mutate(
    ids = paste_rows(id),
    organizations = paste_rows(organization)
  ) %>%
  ungroup() %>%
  distinct(name, n_trials, ids, organizations) %>%
  # arrange(desc(n_trials)) %>%
  arrange(name) %>%
  mutate(email = NA, email_source = NA)

nrow(charite_contacts_missing_email)

write_csv(charite_contacts_missing_email, here("data", "manual", "charite-contacts-missing-email.csv"))

coded_charite_contacts_missing_email <- read_csv(here("data", "manual", "charite-contacts-missing-email_coded.csv"))

# Compare coded and uncoded
anti_join(charite_contacts_missing_email, coded_charite_contacts_missing_email, by = "name")
anti_join(coded_charite_contacts_missing_email, charite_contacts_missing_email, by = "name")

# We were not able to find emails for for some researchers
coded_charite_contacts_missing_email %>%
  filter(is.na(email)) %>%
  nrow()


# Update charite contacts -------------------------------------------------

tv_charite_contacts <-

  # Update contacts with manually found emails
  coded_charite_contacts_missing_email %>%
  separate_rows(ids, sep = "; ") %>%
  rename(id = ids) %>%
  select(name, id, email) %>%
  rows_update(tv_charite_contacts, ., by = c("name", "id")) %>%

  # Limit to charite organization or email since some contacts only charite *trial* email and 1 contact (Andreas Niedeggen - NCT02096913) with berlin affiliation is *not* charite
  filter(if_any(c(email, organization), ~ str_detect(., "(?i)charit"))) %>%

  # Remove contact without email
  filter(!is.na(email)) %>%

  # Include all contacts for DRKS, and responsible party or study official for ctgov
  filter(registry == "DRKS" |
           (registry == "ClinicalTrials.gov" &
              str_detect(contact_type, "study_official|responsible_party")
           )
  )


# Explore contacts --------------------------------------------------------

# Inspect contact types/positions by registry
tv_contacts %>%
  count(registry, contact_type, position, name = "n_trials") %>%
  arrange(registry, contact_type)

tv_charite_contacts %>%
  count(registry, contact_type, position, name = "n_trials") %>%
  arrange(registry, contact_type)

# Inspect titles
tv_contacts %>%
  count(title) %>%
  arrange(desc(n)) %>%
  drop_na()

# Inspect charite organizations (not tidied)
tv_charite_contacts %>%
  count(organization) %>%
  arrange(organization)

# Inspect contacts with charite organization/email
tv_charite_contacts %>%
  count(str_detect(organization, "Charité"), str_detect(email, "charite"))

# Inspect contacts missing organization or email
tv_charite_contacts %>%
  filter(is.na(organization) | is.na(email))

# Check for email associated with multiple names
tv_contacts %>%
  select(id, name, email) %>%
  group_by(email) %>%
  summarise(across(everything(), paste_rows)) %>%
  filter(!is.na(email) & str_detect(name, ";")) # semicolon divides names

# Inspect contacts with no name (removed)
tv_charite_contacts %>%
  filter(is.na(name)) %>%
  arrange(email)

# Check registry counts
trackvalue %>% count(registry)
tv_charite_contacts %>% distinct(id, .keep_all = TRUE) %>% count(registry)

# Check for tv trials missing charite contacts
anti_join(trackvalue, tv_charite_contacts, by = "id")

# Check for tv trials missing charite contacts *with name*
tv_charite_contacts %>%
  filter(!is.na(name)) %>%
  anti_join(trackvalue, ., by = "id")

# Check for trials with no email for any Charité contact
tv_charite_contacts %>%
  group_by(id) %>%
  mutate(no_email = if_else(all(is.na(email)), TRUE, FALSE)) %>%
  filter(no_email) %>%
  distinct(id) %>%
  ungroup() %>%
  semi_join(tv_charite_contacts, ., by = "id")

# Explore trial study leads (pi/chair/director) for ctgov
ctgov_trials_study_leads <-
  tv_charite_contacts %>%
  group_by(id) %>%
  mutate(
    has_investigator = if_else(any(str_detect(position, "Investigator")), TRUE, FALSE, missing = FALSE),
    has_chair_director = if_else(any(str_detect(position, "Study")), TRUE, FALSE, missing = FALSE),
    has_investigator_chair_director = if_else(any(str_detect(position, "Investigator|Study")), TRUE, FALSE, missing = FALSE)
  ) %>%
  ungroup()

# How many ctgov trials have at least 1 charite study pi/chair/director?
# All have one of pi/chair/director: mostly pi only (n = 111), but also n = 34 with both pi and chair/director, and n = 4 with chair/director only
ctgov_trials_study_leads %>%
  distinct(id, .keep_all = TRUE) %>%
  count(registry, has_investigator, has_investigator_chair_director, has_chair_director)

# Explore trial contacts (pi/chair/director) for drks
drks_trials_study_leads <-
  tv_charite_contacts %>%
  group_by(id) %>%
  mutate(
    has_public = if_else(any(str_detect(contact_type, "contact_for_public_queries")), TRUE, FALSE, missing = FALSE),
    has_scientific = if_else(any(str_detect(contact_type, "contact_for_scientific_queries")), TRUE, FALSE, missing = FALSE),
    has_sponsor = if_else(any(str_detect(contact_type, "primary_sponsor")), TRUE, FALSE, missing = FALSE),

    # "scientific" always precedes "public" (checked visually)
    is_scientific_public = if_else(any(str_detect(contact_type, "contact_for_scientific_queries; contact_for_public_queries")), TRUE, FALSE, missing = FALSE)
  ) %>%
  ungroup()

# How many drks trials have what combinations of contacts?
# Only 2 trials without scientific lead; these also do not have primary sponsor and only have public lead
drks_trials_study_leads %>%
  filter(registry == "DRKS") %>%
  distinct(id, .keep_all = TRUE) %>%
  count(has_scientific, has_public, has_sponsor)

# Which drks trials missing charite scientific lead?
drks_trials_study_leads %>%
  filter(registry == "DRKS" & !has_scientific)

# How many contacts are both scientific and public lead?
drks_trials_study_leads %>%
  filter(registry == "DRKS") %>%
  count(is_scientific_public)


# Structure charite contacts ----------------------------------------------

# tv_charite_contacts: row per trial, per trialist
# tv_charite_contacts_per_trial: row per trial (with all trialists)
# tv_charite_contacts_per_trialist: row per trialist (with all trials)

# Explore multiple contacts per trial
tv_charite_contacts_per_trial <-
  tv_charite_contacts %>%

  group_by(id) %>%

  # How many contacts?
  add_count(name = "n_contacts") %>%

  # Which contacts?
  mutate(contacts = paste_rows(name)) %>%

  ungroup() %>%
  distinct(id, registry, n_contacts, contacts) %>%
  arrange(desc(n_contacts))

# How many trials with each number of contacts per registry?
tv_charite_contacts_per_trial %>%
  count(registry, n_contacts, name = "n_trials")

# For example, which contacts for trial with most contacts?
tv_charite_contacts_per_trial %>%
  slice_head(n = 1) %>%
  semi_join(tv_charite_contacts, ., by = "id") %>%
  select(name, contact_type, title, position)

# Explore multiple trials per contact
tv_charite_contacts_per_trialist <-
  tv_charite_contacts %>%

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

  arrange(desc(n_trials))

# How many contacts with each number of trials per registry?
tv_charite_contacts_per_trialist %>%
  count(n_trials, name = "n_contacts")

# For example, which trials for contact with most trials?
tv_charite_contacts_per_trialist %>%
  slice_head(n = 1) %>%
  semi_join(tv_charite_contacts, ., by = "name") %>%
  select(name, registry, id)

write_csv(tv_charite_contacts, here("data", "processed", "charite-contacts.csv"))
write_csv(tv_charite_contacts_per_trial, here("data", "processed", "charite-contacts-per-trial.csv"))
write_csv(tv_charite_contacts_per_trialist, here("data", "processed", "charite-contacts-per-trialist.csv"))
