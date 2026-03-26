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
#   - Rows: AESOC and AETERM (hierarchical)
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
library(tidyr)

# --- Load input data ----------------------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

# --- Filter treatment-emergent AEs --------------------------------------------
# Filter adae where TRTEMFL == "Y"
# Pre-processing --------------------------------------------
adae <- adae |>
  filter(
    # treatment emergent adverse events
    TRTEMFL == "Y"
  )

# --- Create summary table -----------------------------------------------------
# Build gtsummary table with:
#   - Rows: AESOC (system organ class) and AETERM (reported term), hierarchical
#   - Columns: ACTARM (treatment groups)
#   - Values: n (%)
#   - Total column
#   - Sorted by descending frequency

tbl <- adae |>
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
  ) %>%
  add_overall() |>
  sort_hierarchical()

# Check
tbl

# --- Save output --------------------------------------------------------------
# Save as ae_summary_table.html (static)
tbl %>%
  as_gt() %>%
  gt::gtsave("question_3_tlg/ae_summary_table.html")

# --- Interactive table using {reactable} --------------------------------------
# Searchable/sortable version of the AE summary for exploratory use
library(reactable)

# Build a subject-level summary: count unique subjects per AESOC, AETERM, ACTARM
ae_summary <- adae %>%
  distinct(USUBJID, AESOC, AETERM, ACTARM) %>%
  count(AESOC, AETERM, ACTARM, name = "n_subjects") %>%
  pivot_wider(
    names_from = ACTARM,
    values_from = n_subjects,
    values_fill = 0
  ) %>%
  arrange(AESOC, desc(rowSums(select(., where(is.numeric)))))

rt_table <- reactable(
  ae_summary,
  searchable = TRUE,
  filterable = TRUE,
  sortable = TRUE,
  pagination = TRUE,
  defaultPageSize = 25,
  striped = TRUE,
  highlight = TRUE,
  groupBy = "AESOC",
  columns = list(
    AESOC = colDef(name = "System Organ Class", minWidth = 200),
    AETERM = colDef(name = "Reported Term", minWidth = 200)
  )
)

htmlwidgets::saveWidget(rt_table, "question_3_tlg/ae_summary_interactive.html",
                        selfcontained = TRUE)

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Execution Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
