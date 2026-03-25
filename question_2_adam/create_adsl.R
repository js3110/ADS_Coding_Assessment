# ==============================================================================
# Question 2: ADaM ADSL Dataset Creation using {admiral}
#
# Objective: Create an ADSL (Subject Level) dataset using SDTM source data,
#            {admiral}, and tidyverse tools.
#
# Input:  pharmaversesdtm::dm, pharmaversesdtm::vs, pharmaversesdtm::ex,
#         pharmaversesdtm::ds, pharmaversesdtm::ae
# Output: ADSL dataset with derived variables: AGEGR9, AGEGR9N, TRTSDTM,
#         TRTSTMF, ITTFL, LSTAVLDT
# ==============================================================================

# Start logging
log_file <- "question_2_adam/log.txt"
con <- file(log_file, open = "wt")
sink(con, type = "output")
sink(con, type = "message", append = TRUE)

# Load required libraries
library(admiral)
library(pharmaversesdtm)
library(dplyr)
library(lubridate)

# --- Load SDTM source datasets -----------------------------------------------

dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

# --- Start ADSL from DM ------------------------------------------------------
# DM is the basis of ADSL: one row per subject
adsl <- dm %>%
  select(-DOMAIN)

# --- Derive AGEGR9 and AGEGR9N -----------------------------------------------
# TODO: Age grouping: "<18", "18 - 50", ">50" with numeric 1, 2, 3

# --- Derive TRTSDTM and TRTSTMF ----------------------------------------------
# TODO: First valid exposure datetime with time imputation

# --- Derive ITTFL -------------------------------------------------------------
# TODO: "Y" if ARM is not missing, else "N"

# --- Derive LSTAVLDT ----------------------------------------------------------
# TODO: Last known alive date from VS, AE, DS, and treatment dates

# --- Select and order final variables -----------------------------------------
# TODO: Select relevant ADSL variables

# --- Save output dataset ------------------------------------------------------
# TODO: write.csv(adsl, "question_2_adam/adsl.csv", row.names = FALSE)

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Execution Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
cat("Dimensions:", nrow(adsl), "rows x", ncol(adsl), "columns\n\n")
str(adsl)
cat("\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
