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
# Create bar chart or heatmap
#   - x-axis: treatment group (ACTARM)
#   - fill/color: severity (AESEV)
#   - Save as plot1_ae_severity.png

# --- Plot 1a: Stacked Bar Chart ---
p1_bar <- ggplot(adae, aes(x = ACTARM, fill = AESEV)) +
  geom_bar() +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Count of AEs",
    fill = "Severity/Intensity"
  ) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5))

ggsave("question_3_tlg/plot1_ae_severity_bar.png", p1_bar, width = 8, height = 6)

# --- Plot 1b: Heatmap ---
heatmap_data <- adae %>%
  count(ACTARM, AESEV)

p1_heat <- ggplot(heatmap_data, aes(x = ACTARM, y = AESEV, fill = n)) +
  geom_tile(color = "white") +
  geom_text(aes(label = n), size = 5) +
  scale_fill_gradient(low = "lightyellow", high = "red") +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Severity/Intensity",
    fill = "Count"
  )

ggsave("question_3_tlg/plot1_ae_severity_heatmap.png", p1_heat, width = 8, height = 5)


# --- Plot 2: Top 10 Most Frequent AEs with 95% CI ----------------------------
# Calculate incidence rates and 95% CI for top 10 AEs
#   - Identify top 10 AEs by frequency (AETERM)
#   - Calculate incidence rate per treatment group
#   - Add 95% confidence intervals
#   - Save as plot2_top10_ae.png

# Total number of subjects
n_total <- n_distinct(adsl$USUBJID)

# Count subjects per AETERM, get top 10
top10 <- adae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, sort = TRUE) %>%
  slice_head(n = 10) %>%
  mutate(
    pct = n / n_total * 100,
    ci_low = qbeta(0.025, n, n_total - n + 1) * 100,
    ci_high = qbeta(0.975, n + 1, n_total - n) * 100
  )

p2 <- ggplot(top10, aes(x = pct, y = reorder(AETERM, pct))) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), width = 0.2) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", n_total, " subjects; 95% Clopper-Pearson CIs"),
    x = "Percentage of Patients (%)",
    y = NULL
  ) +
  theme(panel.grid.minor = element_blank())

ggsave("question_3_tlg/plot2_top10_ae.png", p2, width = 8, height = 6)

# --- Log summary --------------------------------------------------------------
cat("\n\n=== Visualization Summary ===\n")
cat("Date:", format(Sys.time()), "\n")
sessionInfo()

# Stop logging
sink(type = "message")
sink(type = "output")
close(con)
