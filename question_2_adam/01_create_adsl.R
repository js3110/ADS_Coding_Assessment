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
library(pharmaversesdtm)
library(admiral)
library(dplyr)
library(tidyr)

# Read in input SDTM data
dm <- pharmaversesdtm::dm
ds <- pharmaversesdtm::ds
ex <- pharmaversesdtm::ex
ae <- pharmaversesdtm::ae
vs <- pharmaversesdtm::vs

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

adsl <- derive_vars_cat(
  dataset = adsl,
  definition = agegr9_lookup
)
# --- Derive TRTSDTM and TRTSTMF and TRTESDTM ----------------------------------------------
# First valid exposure datetime with time imputation

# Derive EXSTDTM and EXSTTMF from EXSTDTC
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "h",
    flag_imputation = "time"
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    time_imputation = "last"
  )

# Treatment Start Datetime
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  # Treatment End Datetime
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  )
# --- Derive ITTFL -------------------------------------------------------------
# "Y" if ARM is not missing, else "N"
adsl <- adsl %>%
  mutate(ITTFL = ifelse(is.na(ARM), "N", "Y"))

# --- Derive LSTAVLDT ----------------------------------------------------------
#  Last known alive date from VS, AE, DS, and treatment dates
# VS: convert VSDTC to date, filter valid results
vs_dt <- vs %>%
  mutate(ADT = convert_dtc_to_dt(VSDTC))

# AE: convert AESTDTC to date
ae_dt <- ae %>%
  mutate(ADT = convert_dtc_to_dt(AESTDTC))

# DS: convert DSSTDTC to date
ds_dt <- ds %>%
  mutate(ADT = convert_dtc_to_dt(DSSTDTC))

adsl <- adsl %>%
  derive_vars_dtm_to_dt(exprs(TRTEDTM))

# Combine all dates and find the last date per subject
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        dataset_name = "vs",
        condition = !is.na(ADT) &
          !(is.na(VSSTRESN) & is.na(VSSTRESC)), # Check valid results
        order = exprs(ADT),
        mode = "last",
        set_values_to = exprs(LSTAVLDT = ADT)
      ),
      event(
        dataset_name = "ae",
        condition = !is.na(ADT),
        order = exprs(ADT),
        mode = "last",
        set_values_to = exprs(LSTAVLDT = ADT)
      ),
      event(
        dataset_name = "ds",
        condition = !is.na(ADT),
        order = exprs(ADT),
        mode = "last",
        set_values_to = exprs(LSTAVLDT = ADT)
      ),
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDTM),
        order = exprs(TRTEDTM),
        mode = "last",
        set_values_to = exprs(LSTAVLDT = TRTEDT)
      )
    ),
    source_datasets = list(vs = vs_dt, ae = ae_dt, ds = ds_dt, adsl = adsl),
    order = exprs(LSTAVLDT),
    mode = "last",
    new_vars = exprs(LSTAVLDT)
  )

# --- Select and order final variables -----------------------------------------
# Select relevant ADSL variables
adsl_final <- adsl %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, SEX, RACE, ETHNIC,
    ARM, ARMCD, ACTARM, ACTARMCD,
    AGEGR9, AGEGR9N, TRTSDTM, TRTSTMF, TRTEDTM, TRTETMF,
    ITTFL, LSTAVLDT
  )

# --- Save output dataset ------------------------------------------------------

write.csv(adsl_final, "question_2_adam/adsl.csv", row.names = FALSE)

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Execution Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
cat("Dimensions:", nrow(adsl_final), "rows x", ncol(adsl_final), "columns\n\n")
str(adsl_final)
cat("\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
