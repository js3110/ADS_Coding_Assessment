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

# Load required libraries
library(sdtm.oak)
library(admiral)
library(pharmaverseraw)
library(ggplot2)
library(pharmaversesdtm)

# Load raw data and controlled terminology
ds_raw <- pharmaverseraw::ds_raw
study_ct <- read.csv("question_1_sdtm/sdtm_ct.csv")
# Read in DM domain
dm <- pharmaversesdtm::dm

# Map raw variables to SDTM variables using sdtm.oak
# Create oak ID vars
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

ds <-
  # Derive topic variable
  # Map DSTERM using assign_no_ct, raw_var=IT.DSTERM, tgt_var=DSTERM
  assign_no_ct(
    raw_dat = ds_raw,
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) # Check this- pdf says if OTHERSP is NULL then we map this

# ds <- ds %>%
#   # Map AEACN using assign_no_ct, raw_var=IT.AEACN, tgt_var=AEACN
#   assign_no_ct(
#     raw_dat = ds_raw,
#     raw_var = "IT.AEACN",
#     tgt_var = "AEACN",
#     id_vars = oak_id_vars()
#   ) %>%
#   # # Map AESHOSP using assign_ct, raw_var=IT.AESHOSP, tgt_var=AESHOSP
#   # assign_ct(
#   #   raw_dat = ds_raw,
#   #   raw_var = "",
#   #   tgt_var = "DSCAT",
#   #   ct_spec = study_ct,
#   #   ct_clst = "C74558",
#   #   id_vars = oak_id_vars()
#   # ) %>%
#   # Map AEDTC using assign_datetime, raw_var=AEDTCOL
#   assign_datetime(
#     raw_dat = ae_raw,
#     raw_var = "AEDTCOL",
#     tgt_var = "AEDTC",
#     raw_fmt = c("m/d/y")
#   )
# 
# # TODO: Derive additional variables (DSSEQ, DSSTDY, etc.)
# derive_seq(
#   tgt_var = "DSSEQ",
#   rec_vars = c("USUBJID", "DSTERM")
)
# TODO: Select and order final variables

# TODO: Save output dataset