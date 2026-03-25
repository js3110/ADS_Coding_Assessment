# ADS Coding Assessment

## Project Goal
Pharmaverse expertise and Python coding assessment — practical exercises focused on clinical trial reporting using CDISC standards (SDTM, ADaM), Pharmaverse R packages, and Python for data science.

## Languages
- R (primary, version ≥ 4.2.0)
- Python (secondary — question 4 only)

## Frameworks & Libraries
### R
- **Pharmaverse:** `admiral`, `sdtm.oak`, `pharmaversesdtm`, `pharmaverseraw`, `pharmaverseadam`
- **Data manipulation:** `dplyr`, `tidyr`
- **Visualization / tables:** `ggplot2`, `gt`, `gtsummary`
- **Testing:** `testthat`

### Python
- **LLM / AI:** `langchain`, `openai`
- **Data:** `pandas`

## Package Managers
- R: CRAN via `install.packages()`
- Python: `pip` / `requirements.txt`

## Standards
- **SDTM** (Study Data Tabulation Model) — CDISC SDTM IG v3.4
- **ADaM** (Analysis Data Model) — CDISC ADaM IG

## DevOps
- Dev container: Ona base image (`eu.repository.roche.com/cde-gitpod-docker-prd-l/ona-base:2.0`)

## Conventions
### Code Style
- R: tidyverse style guide (https://style.tidyverse.org/)
- Python: PEP 8

### Documentation
- Include comments explaining key logic, especially for derivations
- Functions should be well-documented

### Commit Messages
- Conventional commits (e.g., `docs: add AGENTS.md`, `feat: create DS domain script`)
- Commit frequently in short iterations
- Always ask before pushing

### Comments
- Conventional comments (e.g., `# TODO:`, `# FIXME:`, `# NOTE:`, `# HACK:`)

## Working Mode
- **Guided implementation:** Ona explains concepts first, user writes code, Ona reviews and fills gaps.
- **No black boxes:** every non-obvious line gets a comment; user must be able to explain all code.
- **Understanding checks:** 1–2 quick questions before moving to the next section.
- **Question order:** Q1 (SDTM) → Q2 (ADaM) → Q3 (TLG) → Q4 (Python).

---

## Folder Structure

```
question_1_sdtm/
  01_create_ds_domain.R        # SDTM DS domain creation
  ds_domain.<format>           # Output dataset
  log.txt                      # Execution log

question_2_adam/
  create_adsl.R                # ADaM ADSL creation
  adsl.<format>                # Output dataset
  log.txt                      # Execution log

question_3_tlg/
  01_create_ae_summary_table.R # AE summary table
  02_create_visualizations.R   # AE visualizations
  ae_summary_table.html        # Summary table output (or .docx/.pdf)
  plot1_ae_severity.png        # AE severity distribution
  plot2_top10_ae.png           # Top 10 AEs with 95% CI
  log.txt                      # Execution log

question_4_python/
  clinical_data_agent.py       # ClinicalTrialDataAgent class
  test_queries.py              # 3 example queries with printed results
  adae.csv                     # Input data (exported from pharmaversesdtm::ae)
```

---

## Question Specifications

### Question 1: SDTM DS Domain Creation using {sdtm.oak}

**Objective:** Create an SDTM Disposition (DS) domain dataset from raw clinical trial data.

**Input data:**
- `pharmaverseraw::ds_raw`
- `study_ct` — study controlled terminology (download from GitHub or construct manually)

**study_ct construction (fallback):**
```r
study_ct <-
  data.frame(
    stringsAsFactors = FALSE,
    codelist_code = c("C66727","C66727","C66727","C66727","C66727","C66727","C66727","C66727","C66727","C66727"),
    term_code = c("C41331","C25250","C28554","C48226","C48227","C48250","C142185","C49628","C49632","C49634"),
    term_value = c("ADVERSE EVENT","COMPLETED","DEATH","LACK OF EFFICACY","LOST TO FOLLOW-UP","PHYSICIAN DECISION","PROTOCOL VIOLATION","SCREEN FAILURE","STUDY TERMINATED BY SPONSOR","WITHDRAWAL BY SUBJECT"),
    collected_value = c("Adverse Event","Complete","Dead","Lack of Efficacy","Lost To Follow-Up","Physician Decision","Protocol Violation","Trial Screen Failure","Study Terminated By Sponsor","Withdrawal by Subject"),
    term_preferred_term = c("AE","Completed","Died",NA,NA,NA,"Violation","Failure to Meet Inclusion/Exclusion Criteria",NA,"Dropout"),
    term_synonyms = c("ADVERSE EVENT","COMPLETE","Death",NA,NA,NA,NA,NA,NA,"Discontinued Participation")
  )
```

**Required output variables:** STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY

**Hint:** Very similar to the AE example in Pharmaverse Examples.

**References:**
- sdtm.oak docs: https://pharmaverse.github.io/sdtm.oak/
- Pharmaverse SDTM examples: https://pharmaverse.github.io/examples/ (SDTM section)
- Workshop slides/videos: https://pharmaverse.github.io/rinpharma-SDTM-workshop/

---

### Question 2: ADaM ADSL Dataset Creation using {admiral}

**Objective:** Create an ADSL (Subject Level) dataset using SDTM source data, {admiral}, and tidyverse.

**Input data:**
- `pharmaversesdtm::dm` (basis of ADSL)
- `pharmaversesdtm::vs`
- `pharmaversesdtm::ex`
- `pharmaversesdtm::ds`
- `pharmaversesdtm::ae`

**Variables to derive:**

| Variable | Specification |
|---|---|
| **AGEGR9** | Age grouping: "<18", "18 - 50", ">50" |
| **AGEGR9N** | Numeric age grouping: 1, 2, 3 (corresponding to AGEGR9 categories) |
| **TRTSDTM** | Datetime of first valid exposure (EX.EXSTDTC). Valid dose = EXDOSE > 0 OR (EXDOSE == 0 AND EXTRT contains "PLACEBO"). Datepart must be complete. Impute missing time with 00:00:00; partially missing time with 00 for missing components. |
| **TRTSTMF** | Time imputation flag for TRTSDTM. Do NOT populate if only seconds are missing. |
| **ITTFL** | "Y" if DM.ARM is not missing, else "N" |
| **LSTAVLDT** | Last known alive date = max of: (1) last complete VS date with valid result (VSSTRESN and VSSTRESC not both missing, datepart of VSDTC not missing), (2) last complete AE onset date (datepart of AESTDTC), (3) last complete disposition date (datepart of DSSTDTC), (4) last treatment date where valid dose received (datepart of TRTEDTM) |

**Hint:** Similar to ADSL example in Pharmaverse Examples or admiral docs: https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html

**References:**
- admiral docs: https://pharmaverse.github.io/admiral/
- Pharmaverse ADaM examples: https://pharmaverse.github.io/examples/ (ADaM section)

---

### Question 3: TLG — Adverse Events Reporting

**Objective:** Create AE summary outputs using {gtsummary} and {ggplot2}.

**Input data:**
- `pharmaverseadam::adae`
- `pharmaverseadam::adsl`

**Task 1: Summary Table (gtsummary) — similar to FDA Table 10**
- Filter: treatment-emergent AEs only (`TRTEMFL == "Y"`)
- Rows: AETERM or AESOC
- Columns: treatment groups (ACTARM)
- Cell values: count (n) and percentage (%)
- Include total column
- Sort by descending frequency
- Output: `ae_summary_table.html` (or .docx/.pdf)

**Task 2: Visualizations (ggplot2)**
- **Plot 1:** AE severity distribution by treatment (bar chart or heatmap). Severity variable: `AESEV`. Output: PNG.
- **Plot 2:** Top 10 most frequent AEs with 95% CI for incidence rates. AE variable: `AETERM`. Output: PNG.

**References:**
- ggplot2 docs: https://ggplot2.tidyverse.org/
- FDA TLG Catalogue: https://pharmaverse.github.io/cardinal/quarto/index-catalog.html
- Pharmaverse TLG examples: https://pharmaverse.github.io/examples/ (TLG section)

---

### Question 4: GenAI Clinical Data Assistant (Python — Bonus)

**Objective:** Build a Generative AI assistant that translates natural language questions into Pandas queries against an AE dataset.

**Input data:**
- `adae.csv` — exported from `pharmaversesdtm::ae`

**Architecture:**
1. **Schema Definition:** Define a dictionary or string describing relevant columns (AESEV, AETERM, AESOC, etc.) so the LLM understands the dataset structure.
2. **LLM Implementation:** Create a `ClinicalTrialDataAgent` class/function that uses an LLM (e.g., OpenAI via LangChain) to parse a user's natural language question into structured JSON:
   - `target_column`: the column to filter
   - `filter_value`: the value to search for (extracted from the question)
3. **Execution:** Apply the LLM's parsed output as a Pandas filter. Return count of unique subjects (`USUBJID`) and list of matching IDs.

**Column mapping examples:**
- "severity" / "intensity" → `AESEV`
- Specific condition (e.g., "Headache") → `AETERM`
- Body system (e.g., "Cardiac", "Skin") → `AESOC`

**API Key:** Use own OpenAI key or mock the LLM response. If mocked, the full logic flow (Prompt → Parse → Execute) must still be implemented.

**Deliverables:**
- `clinical_data_agent.py` — agent implementation
- `test_queries.py` — runs 3 example queries and prints results
- Example query: "Give me the subjects who had Adverse events of Moderate severity"

---

## Key References
- Pharmaverse examples: https://pharmaverse.github.io/examples/
- admiral docs: https://pharmaverse.github.io/admiral/
- sdtm.oak docs: https://pharmaverse.github.io/sdtm.oak/
- CDISC SDTM IG: https://www.cdisc.org/standards/foundational/sdtmig
- CDISC ADaM IG: https://www.cdisc.org/standards/foundational/adam
- FDA TLG Catalogue: https://pharmaverse.github.io/cardinal/quarto/index-catalog.html
- Coursera: Hands On Clinical Reporting Using R
