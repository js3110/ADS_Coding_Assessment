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
library(metacore)
library(metatools)
library(pharmaversesdtm)
library(admiral)
library(xportr)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)

# Read in input SDTM data
dm <- pharmaversesdtm::dm
ds <- pharmaversesdtm::ds
ex <- pharmaversesdtm::ex
ae <- pharmaversesdtm::ae
vs <- pharmaversesdtm::vs
suppdm <- pharmaversesdtm::suppdm

# Combine Parent and Supp
dm_suppdm <- combine_supp(dm, suppdm)

# Read in metacore object
metacore <- spec_to_metacore(
  path = "./question_2_adam/safety_specs.xlsx",
  # All datasets are described in the same sheet
  where_sep_sheet = FALSE
) %>%
  select_dataset("ADSL")

# --- Start ADSL from DM ------------------------------------------------------
# DM is the basis of ADSL: one row per subject
adsl <- dm %>%
  select(-DOMAIN)

# --- Derive AGEGR9 and AGEGR9N -----------------------------------------------
# Age grouping: "<18", "18 - 50", ">50" with numeric 1, 2, 3
agegr9_lookup <- exprs(
  ~condition,            ~AGEGR9, ~AGEGR9N,
  is.na(AGE),          "Missing",        4,
  AGE < 18,                "<18",        1,
  between(AGE, 18, 50),  "18 - 50",        2,
  !is.na(AGE),             ">50",        3
)

adsl_cat <- derive_vars_cat(
  dataset = adsl,
  definition = agegr9_lookup
)
# --- Derive TRTSDTM and TRTSTMF ----------------------------------------------
# TODO: First valid exposure datetime with time imputation

# Derive EXSTDTM and EXSTTMF from EXSTDTC
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "h",
    flag_imputation = "time"
  )

# Treatment Start Datetime
adsl_cat <- adsl_cat %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  )
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
