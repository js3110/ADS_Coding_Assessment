# ==============================================================================
# Question 1: SDTM DS Domain Creation using {sdtm.oak}
#
# Objective: Create an SDTM Disposition (DS) domain dataset from raw clinical
#            trial data using {sdtm.oak}.
#
# Input:  pharmaverseraw::ds_raw, study_ct (controlled terminology)
# Output: DS domain with variables: STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM,
#         DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
# ==============================================================================

# Start logging all console output to prove error-free execution
log_file <- "question_1_sdtm/log.txt"
con <- file(log_file, open = "wt")
sink(con, type = "output")
sink(con, type = "message", append = TRUE)

# Load required libraries
library(sdtm.oak)
library(admiral)
library(pharmaverseraw)
library(pharmaversesdtm)
library(dplyr)

# Load raw data and controlled terminology
ds_raw <- pharmaverseraw::ds_raw
dm <- pharmaversesdtm::dm
study_ct <- read.csv("question_1_sdtm/sdtm_ct.csv")

# Map raw variables to SDTM variables using sdtm.oak
# Create oak ID vars
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

# Start mapping DS domain
ds <-
  # Map DSTERM from IT.DSTERM for non-OTHER EVENT records
  assign_no_ct(
    raw_dat = ds_raw,
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  # For records where IT.DSTERM is NA, use OTHERSP
  assign_no_ct(
    raw_dat = ds_raw %>% condition_add(!is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  # Map DSCAT based on OTHERSP and IT.DSDECOD values
  # DSCAT = "PROTOCOL MILESTONE" when Randomized
  hardcode_ct(
    raw_dat = ds_raw %>% condition_add(IT.DSDECOD == "Randomized"),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  # DSCAT = "OTHER EVENT" when OTHERSP is populated
  hardcode_ct(
    raw_dat = ds_raw %>% condition_add(!is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  # DSCAT = "DISPOSITION EVENT" for the rest
  hardcode_ct(
    raw_dat = ds_raw %>% condition_add(
      is.na(OTHERSP) & (IT.DSDECOD != "Randomized" | is.na(IT.DSDECOD))
    ),
    raw_var = "IT.DSTERM",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  # DSDECOD from IT.DSDECOD when OTHERSP is null
  # NOTE: DSDECOD officially has CT however aCRF instructs to map as below
  assign_no_ct(
    raw_dat = ds_raw %>% condition_add(
      is.na(OTHERSP)
      ),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) %>%
  # DSDECOD from OTHERSP when OTHERSP is not null
  assign_no_ct(
    raw_dat = ds_raw %>% condition_add(!is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  )

# Map date/time variables
ds <- ds %>%
  # Map DSDTC from DSDTCOL (date) and DSTMCOL (time)
  # NOTE: assign_datetime was giving error (Can't combine `true` <iso8601> and `false` <iso8601>.)
  # So here we manually create iso8601
  mutate(
    DSDTC = as.character(
      create_iso8601(ds_raw$DSDTCOL, ds_raw$DSTMCOL, .format = c("m-d-y", "H:M"))
    )
  ) %>%
  # Map DSSTDTC from IT.DSSTDAT
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m-d-y"),
    id_vars = oak_id_vars()
  ) %>%
  
  # Map VISIT and VISITNUM
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  )

# Derive additional variables (DSSEQ, DSSTDY, etc.)

ds <- ds %>%
  dplyr::mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM),
    DSTERM = toupper(DSTERM),
    DSDECOD = toupper(DSDECOD)
  ) %>%
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSTERM")
  ) %>%
  derive_study_day(
    sdtm_in = .,
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  )

# Select and order final variables

ds <- ds %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD,
    DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  )
# Save output dataset
write.csv(ds, "question_1_sdtm/ds_domain.csv", row.names = FALSE)

# Log summary info
cat("\n\n=== Execution Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
cat("Dimensions:", nrow(ds), "rows x", ncol(ds), "columns\n\n")
str(ds)
cat("\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)