# ADS Coding Assessment

Pharmaverse and Python coding assessment covering clinical trial reporting using CDISC standards (SDTM, ADaM), Pharmaverse R packages, and Python for data science.

## Prerequisites

- **R** (>= 4.2.0) with packages: `sdtm.oak`, `admiral`, `pharmaverseraw`, `pharmaversesdtm`, `pharmaverseadam`, `dplyr`, `stringr`, `gtsummary`, `gt`, `ggplot2`
- **Python** (>= 3.10) with packages listed in `question_4_python/requirements.txt`

## Project Structure

```
question_1_sdtm/           # SDTM DS Domain Creation
  01_create_ds_domain.R     # Main script
  sdtm_ct.csv               # Controlled terminology
  ds_domain.csv             # Output dataset (850 rows x 12 cols)
  log.txt                   # Execution log

question_2_adam/            # ADaM ADSL Dataset Creation
  01_create_adsl.R          # Main script
  adsl.csv                  # Output dataset (306 rows x 21 cols)
  log.txt                   # Execution log

question_3_tlg/             # AE Reporting (Tables & Visualizations)
  01_create_ae_summary_table.R  # Summary table script
  02_create_visualizations.R    # Visualization script
  ae_summary_table.html         # Hierarchical AE summary table
  plot1_ae_severity_bar.png     # Stacked bar chart — severity by treatment
  plot1_ae_severity_heatmap.png # Heatmap — severity by treatment
  plot2_top10_ae.png            # Top 10 AEs with 95% Clopper-Pearson CIs
  log.txt                       # Execution log

question_4_python/          # GenAI Clinical Data Assistant
  clinical_data_agent.py    # ClinicalTrialDataAgent class
  test_queries.py           # 3 example queries with results
  adae.csv                  # Input data (pharmaversesdtm::ae)
  requirements.txt          # Python dependencies
```

## Question 1: SDTM DS Domain

**Objective:** Create an SDTM Disposition (DS) domain from raw clinical trial data using `{sdtm.oak}`.

**Approach:**
- Used `generate_oak_id_vars()` to create oak ID variables from `pharmaverseraw::ds_raw`
- Mapped DSTERM from `IT.DSTERM` (disposition events) and `OTHERSP` (other events) using `assign_no_ct()` with `condition_add()` to handle the two sources
- Derived DSCAT based on two rules: `IT.DSDECOD == "Randomized"` → PROTOCOL MILESTONE, `OTHERSP` not null → OTHER EVENT, otherwise → DISPOSITION EVENT
- DSDECOD mapped without controlled terminology (as per CRF instructions) from `IT.DSDECOD` or `OTHERSP`
- Dates converted using `create_iso8601()` (manual approach due to a `assign_datetime` bug with combined date+time columns in sdtm.oak 0.2.0)
- DSSEQ and DSSTDY derived using `derive_seq()` and `derive_study_day()`

**Key decisions:**
- DSDECOD mapped with `assign_no_ct()` instead of `assign_ct()` because the study controlled terminology `collected_value` entries did not match the raw data values, and the CRF instructions support direct mapping
- Added C114118 codelist entry for "RANDOMIZED" (protocol milestone) to the study CT

## Question 2: ADaM ADSL

**Objective:** Create an ADSL (Subject-Level) dataset using `{admiral}` and tidyverse.

**Derived variables:**

| Variable | Method |
|---|---|
| AGEGR9 / AGEGR9N | `derive_vars_cat()` with lookup table: <18 (1), 18-50 (2), >50 (3) |
| TRTSDTM / TRTSTMF | `derive_vars_dtm()` on EX with `highest_imputation = "h"`, then `derive_vars_merged()` with valid dose filter, mode = "first" |
| TRTEDTM / TRTETMF | Same approach with `EXENDTC`, `time_imputation = "last"`, mode = "last" |
| ITTFL | `mutate()` — "Y" if ARM is not missing, else "N" |
| LSTAVLDT | `derive_vars_extreme_event()` across 4 sources: VS (valid results only), AE (onset dates), DS (disposition dates), ADSL (TRTEDT) |

**Key decisions:**
- Valid dose filter: `EXDOSE > 0 OR (EXDOSE == 0 AND EXTRT contains "PLACEBO")`
- TRTEDTM uses `time_imputation = "last"` (23:59:59) — conservative for end dates
- LSTAVLDT VS source filters for records where VSSTRESN and VSSTRESC are not both missing

## Question 3: TLG — Adverse Events Reporting

**Task 1: Summary Table**
- Filtered treatment-emergent AEs (`TRTEMFL == "Y"`)
- Built hierarchical table (AESOC → AETERM) using `tbl_hierarchical()` from `{gtsummary}`
- Denominator from ADSL (N per treatment arm)
- Sorted by descending frequency using `sort_hierarchical()`
- Added overall column with `add_overall()`

**Task 2: Visualizations**
- **Plot 1a:** Stacked bar chart of AE severity (AESEV) by treatment arm (ACTARM)
- **Plot 1b:** Heatmap of AE counts by severity and treatment (bonus)
- **Plot 2:** Top 10 most frequent AEs (by unique subject count) with 95% Clopper-Pearson exact binomial confidence intervals

## Question 4: GenAI Clinical Data Assistant

**Objective:** Natural language → Pandas query pipeline for AE data.

**Architecture:**
```
User Question → _build_prompt() → _call_llm() → _parse_response() → _execute_query()
                     │                  │                │                  │
              Injects CDISC      Mock or OpenAI    JSON parsing      Pandas filter
              schema + data      via LangChain     + validation      + unique USUBJIDs
```

**Key features:**
- **CDISC-based schema:** All 35 AE domain variables defined with SDTM IG descriptions
- **Auto-generated schema:** `build_schema_from_data()` reads the CSV and includes actual unique values, giving the LLM full context
- **Synonym mapping:** `COLUMN_SYNONYMS` dictionary maps natural language terms (e.g., "severity", "hospitalization", "fatal") to SDTM column names
- **Mock LLM:** Rule-based keyword matching that simulates LLM behavior — covers severity, seriousness, body system, causality, outcome, action taken, life-threatening, death, and hospitalization queries
- **Real LLM:** OpenAI integration via LangChain (`ChatOpenAI`) — drop-in replacement by setting `use_mock=False` and providing an API key
- **Flexible matching:** `str.contains()` for partial, case-insensitive matching

**Running the agent:**
```bash
cd question_4_python
pip install -r requirements.txt
python test_queries.py
```

## Running the Scripts

Each R script is self-contained and generates its own log file:

```r
# From the project root
source("question_1_sdtm/01_create_ds_domain.R")
source("question_2_adam/01_create_adsl.R")
source("question_3_tlg/01_create_ae_summary_table.R")
source("question_3_tlg/02_create_visualizations.R")
```

Log files capture all console output (including warnings) as evidence of error-free execution.
