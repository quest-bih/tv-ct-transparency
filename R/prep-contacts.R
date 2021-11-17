# Prepare contact based on AACT (for all IntoValue) plus ClinicaTrials.gov and DRKS historical versions (for TrackValue only, sent as csv by bgc on 2021-11-09)

library(dplyr)
library(stringr)
library(readr)
library(fs)
library(jsonlite)

# Get data ----------------------------------------------------------------

trackvalue <-
  read_csv(here::here("data", "processed", "trackvalue.csv"))

# Get AACT data from other repo (TODO: change to github)
iv_repo <- path(path_abs(".."), "intovalue-data")

aact_contacts <- read_rds(path(iv_repo, "data", "processed", "registries", "ctgov", "ctgov-contacts.rds"))
aact_lead_affiliations <- read_rds(path(iv_repo, "data", "processed", "registries", "ctgov", "ctgov-lead-affiliations.rds"))
aact_facility_affiliations <- read_rds(path(iv_repo, "data", "processed", "registries", "ctgov", "ctgov-facility-affiliations.rds"))

# Get historical data
h_ctgov <- read_csv(here::here("data", "raw", "2021-11-09_historical_versions-clinicaltrials.gov.csv"))
h_drks <- read_csv(here::here("data", "raw", "2021-11-09_historical_versions-drks.csv"))


# Prepare aact ------------------------------------------------------------
# AACT sample includes all of intovalue so limit to trackvalue

tv_aact_contacts <-
  aact_contacts %>%
  rename(id = nct_id) %>%
  semi_join(trackvalue, by = "id") %>%
  select(-facility_id)

tv_aact_lead_affiliations <-
  aact_lead_affiliations %>%
  rename(id = nct_id) %>%
  semi_join(trackvalue, by = "id") %>%
  tidyr::drop_na(lead_affiliation) %>%
  rename(affiliation = lead_affiliation) %>%
  mutate(affiliation_type = case_when(
    affiliation_type == "Sponsor" ~ "sponsor",
    affiliation_type == "Responsible Party" ~ "responsible_party",
    affiliation_type == "Study Official" ~ "study_official"
  )) %>%
  distinct()

# Limit facility affiliations to trackvalue and likely Charite
tv_aact_facility_affiliations <-
  aact_facility_affiliations %>%
  rename(id = nct_id) %>%
  semi_join(trackvalue, by = "id") %>%
  filter(country == "Germany") %>%
  filter(str_detect(city, "Berlin")) %>%
  mutate(facility_affiliation = str_c(facility_affiliation, city, sep = ", ")) %>%
  select(-country, -city) %>%
  tidyr::drop_na(facility_affiliation) %>%
  mutate(affiliation_type = "facility") %>%
  rename(affiliation = facility_affiliation) %>%
  distinct()

tv_aact_affiliations <-
  bind_rows(tv_aact_lead_affiliations, tv_aact_facility_affiliations) %>%
  rename(
    contact_type = affiliation_type,
    organization = affiliation
  )

# Prepare historical ctgov ------------------------------------------------
h_ctgov_contacts <-
  h_ctgov %>%
  select(id = nctid, version_number, contacts) %>%

  # Extract contacts from json
  mutate(contacts = purrr::map(contacts, ~ fromJSON(.) %>% as.data.frame())) %>%
  tidyr::unnest(contacts) %>%

  # Keep each unique contact, with latest version number
  group_by(id) %>%
  arrange(desc(version_number)) %>%
  ungroup() %>%
  distinct(id, label, content, .keep_all = TRUE) %>%

  # Tidy contact info
  mutate(
    email = str_extract(content, "Email: .+$"),
    content = str_remove(content, "Email: .+$"),
    email = str_remove(email, "Email: "),

    phone = str_extract(content, "Telephone: .+$"),
    content = str_remove(content, "Telephone: .+$"),
    phone = str_remove(phone, "Telephone: "),

    label = str_remove(label, ":$"),
    label = case_when(
      label == "Central Contact Person" ~ "central_primary",
      label == "Central Contact Backup" ~ "central_backup",
      label == "Study Officials" ~ "study_official"
    )
  ) %>%
  rename(
    contact_type = label,
    name = content
  ) %>%
  arrange(id) %>%

  # Version number not needed
  select(-version_number)


# Prepare historical drks -------------------------------------------------
#TODO: parsing issues
# h_drks_contacts <-
#   h_drks %>%
#   select(id = drksid, version_number, contacts) %>%
#
#   # Extract contacts from json
#   mutate(contacts = purrr::map(contacts, ~ fromJSON(.) %>% as.data.frame())) %>%
#   tidyr::unnest(contacts) %>%
#
#   # Keep each unique contact, with latest version number
#   group_by(id) %>%
#   arrange(desc(version_number)) %>%
#   ungroup() %>%
#   distinct(id, label, content, .keep_all = TRUE)

# Combine aact and historical ---------------------------------------------

#NOTE: right now including `tv_aact_affiliations` but hopefully get from murph with human names...

tv_contacts <-
  bind_rows(tv_aact_contacts, h_ctgov_contacts, tv_aact_affiliations) %>%
  arrange(id) %>%

  # Remove facilities
  filter(!str_detect(contact_type, "facility"))

tv_charite_contacts <-
  tv_contacts %>%

  # Expect charite or berlin in name, email, or organization
  filter(if_any(c(name, email, organization), ~ str_detect(., "(?i)charit|berlin")))

# Visually inspect excluded contacts
tv_non_charite_contacts <- anti_join(tv_contacts, tv_charite_contacts)


# Explore contacts --------------------------------------------------------

# Are there trials with no charite contact?
# 1 ctgov trial (NCT02632292) does not have some charite info...but seems to have online...maybe because charite not first sponsor and maybe aact has 1st sponsor only?
anti_join(trackvalue, tv_charite_contacts, by = "id") %>%
  filter(registry == "ClinicalTrials.gov") %>%
  pull(id) %>%
  cat(sep = "\n")

# How many contact have what info?
# 362 have only organization which isn't very helpful...
tv_charite_contacts %>%
  count(!is.na(name), !is.na(email), !is.na(organization))


# Open issues -------------------------------------------------------------

#TODO: how can we remove "duplicates"? can we collapse across same contact across "duplicates"? E.g., where name in one row and email in another. This would help deduplicate and then we could manually search for emails for remaining contacts with name-only
#We could also filter aact for contact_type == "result" since other should be in historical versions

tv_charite_contacts %>%
  arrange(email) %>%
  distinct(id, contact_type, name, .keep_all = TRUE) # This removes some duplicates but could remove the one with more info...

# How to extract titles for emails?
tv_charite_contacts %>%
  mutate(
    title = str_extract_all(name, "MD|PhD"),
    name = str_remove_all(name, "MD|PhD"),

    # Remove extra spaces and commas (twice since multiple titles)
    name = str_squish(name),
    name = str_remove(name, ",$"),
    name = str_squish(name),
    name = str_remove(name, ",$")
  ) %>%
  filter(id == "NCT00590447")

#NCT00590447

# How many charite contacts per trial? right now could only rough guess because duplicates

# Prioritize by latest version? in which case, keep in version number

#TODO: eventually a dataframe with 1 row per contact with column with all roles
