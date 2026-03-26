# ==============================================================================
# Question 3, Task 2: AE Visualizations using {ggplot2}
#
# Objective: Create two AE visualizations
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output:
#   - plot1_ae_severity.png — AE severity distribution by treatment
#   - plot2_top10_ae.png   — Top 10 most frequent AEs with 95% CI
#
# Requirements:
#   Plot 1: Bar chart or heatmap of AE severity (AESEV) by treatment (ACTARM)
#   Plot 2: Top 10 AEs (AETERM) with 95% CI for incidence rates
# ==============================================================================

# Start logging (append to same log file)
log_file <- "question_3_tlg/log.txt"
con <- file(log_file, open = "at")
sink(con, type = "output")
sink(con, type = "message", append = TRUE)

# Load required libraries
library(pharmaverseadam)
library(ggplot2)
library(dplyr)

# --- Load input data ----------------------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

# --- Plot 1: AE Severity Distribution by Treatment ---------------------------
# TODO: Create bar chart or heatmap
#   - x-axis: treatment group (ACTARM)
#   - fill/color: severity (AESEV)
#   - Save as plot1_ae_severity.png

# --- Plot 2: Top 10 Most Frequent AEs with 95% CI ----------------------------
# TODO: Calculate incidence rates and 95% CI for top 10 AEs
#   - Identify top 10 AEs by frequency (AETERM)
#   - Calculate incidence rate per treatment group
#   - Add 95% confidence intervals
#   - Save as plot2_top10_ae.png

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Visualization Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
