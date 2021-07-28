library(dplyr)
library(readr)
library(fs)

dir <- dir_create(here::here("data", "raw"))


# INTOVALUE ---------------------------------------------------------------

intovalue <- read_csv("https://github.com/maia-sh/intovalue-data/raw/main/data/processed/intovalue.csv")
# intovalue <- rio::import("https://github.com/maia-sh/intovalue-data/raw/master/data/processed/intovalue.rds")

write_csv(intovalue, path(dir, "intovalue.csv"))

# CROSS-REGISTRATIONS -----------------------------------------------------

intovalue_crossreg <- read_csv("https://github.com/maia-sh/intovalue-data/raw/main/data/raw/cross-registrations.csv")

write_csv(intovalue_crossreg, path(dir, "intovalue-crossreg.csv"))
