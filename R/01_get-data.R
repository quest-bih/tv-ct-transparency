library(dplyr)
library(readr)
library(fs)

dir <- dir_create(here::here("data", "raw"))


# QUERY LOGS --------------------------------------------------------------

download.file(
  "https://github.com/maia-sh/intovalue-data/raw/6b97fb62804aae1bab6c85bd2817baa027207bab/queries.log",
  here::here("data", "queries.log")
)

# INTOVALUE ---------------------------------------------------------------

intovalue <- read_rds("https://github.com/maia-sh/intovalue-data/blob/main/data/processed/trials.rds?raw=true")

write_csv(intovalue, path(dir, "intovalue.csv"))

# CROSS-REGISTRATIONS -----------------------------------------------------

intovalue_crossreg <-
  read_rds("https://github.com/maia-sh/intovalue-data/blob/main/data/processed/trn/cross-registrations.rds?raw=true")

write_csv(intovalue_crossreg, path(dir, "intovalue-crossreg.csv"))
