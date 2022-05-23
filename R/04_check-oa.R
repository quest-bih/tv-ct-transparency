# We manually checked open access status. See protocol: https://osf.io/3upgy/

library(dplyr)
library(here)
library(readr)

trackvalue <-  read_csv(here("data", "processed", "trackvalue.csv"))

oa_checks <- tribble(
  ~doi, ~color, ~color_green_only, ~is_oa, ~is_closed_archivable,

  # accessible version of publication found on journal website
  "10.1016/j.jaci.2016.03.043", "open-unclear", "open-unclear", TRUE, NA,
  "10.1097/eja.0000000000000929", "open-unclear", "open-unclear", TRUE, NA,
  "10.1016/j.jaci.2012.06.047", "open-unclear", "open-unclear", TRUE, NA,
  "10.1200/jco.2011.41.1553","open-unclear", "open-unclear", TRUE, NA,

  # accessible version of publication found in Refubium
  "10.1017/s0033291716001379", "green", "green", TRUE, NA
) %>%

  # Add in trial ids (one row per trial id, so duplicate dois if associated with 2+ trials)
  left_join(select(trackvalue, id, doi), by = "doi")

write_csv(oa_checks, here("data", "manual", "oa-checks.csv"))
