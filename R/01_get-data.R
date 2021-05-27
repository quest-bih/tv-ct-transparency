library(dplyr)
library(readr)
library(fs)

dir <- dir_create(here::here("data", "raw"))


# INTOVALUE ---------------------------------------------------------------

# intovalue <-

#TODO: add path to intovalue_data
# ead_csv(""))

# write_csv(intovalue, path(dir, "intovalue.csv"))


# CROSS-REGISTRATIONS -----------------------------------------------------

# Currently rely on reading data from private repo on MSH computer which will make public later and change the line
# Get data from other repositories, assuming both repositories in same parent directory

dir_repositories <- path_norm(path_wd(".."))
dir_repository <- path(dir_repositories, "reg-pub-link")

intovalue_crossreg <-

  read_rds(path(dir_repository, "data", "processed", "cross-registrations.rds"))

write_csv(intovalue_crossreg, path(dir, "intovalue-crossreg.csv"))
