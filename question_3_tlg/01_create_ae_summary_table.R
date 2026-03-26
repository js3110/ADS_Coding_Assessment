# ==============================================================================
# Question 3, Task 1: AE Summary Table using {gtsummary}
#
# Objective: Create an AE summary table similar to FDA Table 10
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: ae_summary_table.html — AE counts by treatment group
#
# Requirements:
#   - Filter: treatment-emergent AEs only (TRTEMFL == "Y")
#   - Rows: AEDECOD (or AESOC)
#   - Columns: treatment groups (ACTARM)
#   - Cell values: count (n) and percentage (%)
#   - Include total column
#   - Sort by descending frequency
# ==============================================================================

# Start logging
log_file <- "question_3_tlg/log.txt"
con <- file(log_file, open = "wt")
sink(con, type = "output")
sink(con, type = "message", append = TRUE)

# Load required libraries
library(pharmaverseadam)
library(gtsummary)
library(dplyr)
library(gt)

# --- Load input data ----------------------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

# --- Filter treatment-emergent AEs --------------------------------------------
# TODO: Filter adae where TRTEMFL == "Y"

# --- Create summary table -----------------------------------------------------
# TODO: Build gtsummary table with:
#   - Rows: AEDECOD (preferred term) or AESOC (system organ class)
#   - Columns: ACTARM (treatment groups)
#   - Values: n (%)
#   - Total column
#   - Sorted by descending frequency

# --- Save output --------------------------------------------------------------
# TODO: Save as ae_summary_table.html

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Execution Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
