# ==============================================================================
# Question 4: GenAI Clinical Data Assistant
#
# Objective: Build a Generative AI assistant that translates natural language
#            questions into Pandas queries against an AE dataset.
#
# Architecture:
#   1. Schema definition — describe dataset columns for the LLM
#   2. LLM implementation — parse natural language → structured JSON
#   3. Execution — apply parsed filter as Pandas query, return results
#
# Input:  adae.csv (exported from pharmaversesdtm::ae)
# Output: Count of unique subjects + list of matching USUBJIDs
# ==============================================================================

import pandas as pd
import json
import os
import re


# --- Schema Definition --------------------------------------------------------
# CDISC SDTM AE domain variable definitions (SDTM IG v3.4)
# This provides the LLM with standardized clinical data terminology.

CDISC_AE_VARIABLES = {
    "STUDYID": "Study Identifier",
    "DOMAIN": "Domain Abbreviation (AE)",
    "USUBJID": "Unique Subject Identifier",
    "AESEQ": "Sequence Number — unique AE record number per subject",
    "AESPID": "Sponsor-Defined Identifier",
    "AETERM": "Reported Term for the Adverse Event — verbatim text as reported (e.g., HEADACHE, NAUSEA, APPLICATION SITE PRURITUS)",
    "AELLT": "Lowest Level Term — MedDRA lowest level term",
    "AELLTCD": "Lowest Level Term Code — MedDRA code for AELLT",
    "AEDECOD": "Dictionary-Derived Term — MedDRA preferred term (e.g., Headache, Nausea)",
    "AEPTCD": "Preferred Term Code — MedDRA code for AEDECOD",
    "AEHLT": "High Level Term — MedDRA high level term",
    "AEHLTCD": "High Level Term Code",
    "AEHLGT": "High Level Group Term — MedDRA high level group term",
    "AEHLGTCD": "High Level Group Term Code",
    "AEBODSYS": "Body System or Organ Class — MedDRA system organ class (e.g., NERVOUS SYSTEM DISORDERS, CARDIAC DISORDERS)",
    "AEBDSYCD": "Body System or Organ Class Code",
    "AESOC": "Primary System Organ Class — primary SOC for the AE (e.g., CARDIAC DISORDERS, SKIN AND SUBCUTANEOUS TISSUE DISORDERS, GASTROINTESTINAL DISORDERS)",
    "AESOCCD": "Primary System Organ Class Code",
    "AESEV": "Severity/Intensity — severity of the AE. Values: MILD, MODERATE, SEVERE",
    "AESER": "Serious Event — whether the AE is serious. Values: Y, N",
    "AEACN": "Action Taken with Study Treatment — e.g., DOSE NOT CHANGED, DRUG WITHDRAWN, DOSE REDUCED",
    "AEREL": "Causality — relationship of AE to study treatment. Values: PROBABLE, POSSIBLE, REMOTE, NONE",
    "AEOUT": "Outcome of Adverse Event — e.g., RECOVERED/RESOLVED, NOT RECOVERED/NOT RESOLVED, FATAL",
    "AESCAN": "Involves Cancer",
    "AESCONG": "Congenital Anomaly or Birth Defect",
    "AESDISAB": "Persist or Signif Disability/Incapacity",
    "AESDTH": "Results in Death",
    "AESHOSP": "Requires or Prolongs Hospitalization",
    "AESLIFE": "Is Life Threatening",
    "AESOD": "Occurred with Overdose",
    "AEDTC": "Date/Time of Collection",
    "AESTDTC": "Start Date/Time of Adverse Event",
    "AEENDTC": "End Date/Time of Adverse Event",
    "AESTDY": "Study Day of Start of Adverse Event",
    "AEENDY": "Study Day of End of Adverse Event",
}

# Natural language synonyms mapped to column names
COLUMN_SYNONYMS = {
    "AESEV": ["severity", "intense", "intensity", "how severe", "how bad"],
    "AESER": ["serious", "seriousness", "SAE"],
    "AETERM": ["adverse event", "AE term", "reported term", "condition"],
    "AEDECOD": ["preferred term", "coded term", "dictionary term", "PT"],
    "AEBODSYS": ["body system", "organ class", "system organ class", "SOC"],
    "AESOC": ["primary system organ class", "primary SOC"],
    "AEREL": ["relationship", "causality", "related", "relatedness", "causal"],
    "AEOUT": ["outcome", "resolved", "recovered", "result"],
    "AEACN": ["action taken", "action", "dose change", "treatment action"],
    "AESLIFE": ["life threatening", "life-threatening"],
    "AESDTH": ["death", "died", "fatal"],
    "AESHOSP": ["hospitalization", "hospitalisation", "hospital"],
    "AESTDTC": ["start date", "onset date", "when did it start"],
    "AEENDTC": ["end date", "resolution date", "when did it end"],
}


def build_schema_from_data(df: pd.DataFrame) -> str:
    """
    Auto-generate a schema description from the dataset and CDISC definitions.

    Combines CDISC variable definitions with actual unique values from the data
    to give the LLM full context about what's in the dataset.

    Args:
        df: The AE DataFrame

    Returns:
        Schema string for the LLM prompt
    """
    lines = [
        "The dataset contains adverse event (AE) records from a clinical trial.",
        "Each row represents one adverse event for one subject.",
        f"The dataset has {len(df)} records across {df['USUBJID'].nunique()} unique subjects.",
        "",
        "Columns and their descriptions:",
    ]

    for col in df.columns:
        desc = CDISC_AE_VARIABLES.get(col, "No description available")
        unique_count = df[col].nunique()

        # For columns with few unique values, list them
        if unique_count <= 10 and col not in ["USUBJID", "AESEQ", "AESPID"]:
            unique_vals = sorted(df[col].dropna().unique().astype(str).tolist())
            vals_str = ", ".join(unique_vals)
            lines.append(f"- {col}: {desc}. Values: [{vals_str}]")
        else:
            sample = df[col].dropna().head(3).astype(str).tolist()
            sample_str = ", ".join(sample)
            lines.append(f"- {col}: {desc}. Examples: [{sample_str}] ({unique_count} unique values)")

    lines.extend([
        "",
        "Column mapping guide (natural language → column):",
        '- "severity" or "intensity" → AESEV',
        '- "serious" or "SAE" → AESER',
        '- "body system" or "organ class" → AEBODSYS or AESOC',
        '- Specific condition names (e.g., "Headache") → AETERM or AEDECOD',
        '- "relationship" or "causality" → AEREL',
        '- "outcome" or "resolved" → AEOUT',
        '- "action taken" or "dose" → AEACN',
        '- "life threatening" → AESLIFE',
        '- "hospitalization" → AESHOSP',
        '- "death" or "fatal" → AESDTH',
    ])

    return "\n".join(lines)

# --- LLM Prompt Template ------------------------------------------------------

LLM_PROMPT_TEMPLATE = """
You are a clinical data assistant. Given a natural language question about
adverse events in a clinical trial, extract the filtering criteria.

{schema}

Return a JSON object with:
- "target_column": the column name to filter on
- "filter_value": the value to search for (use UPPERCASE for standard terms)

Examples:
- "Show me subjects with severe AEs" → {{"target_column": "AESEV", "filter_value": "SEVERE"}}
- "Which patients had headache?" → {{"target_column": "AETERM", "filter_value": "HEADACHE"}}
- "Subjects with cardiac body system AEs" → {{"target_column": "AESOC", "filter_value": "CARDIAC DISORDERS"}}
- "Give me subjects who had serious adverse events" → {{"target_column": "AESER", "filter_value": "Y"}}

Question: {question}

Return ONLY the JSON object, no other text.
"""


class ClinicalTrialDataAgent:
    """Agent that translates natural language questions into Pandas queries.

    Follows the Prompt → Parse → Execute flow:
    1. Build a prompt with the dataset schema and user question
    2. Send to LLM (or mock) to get structured JSON
    3. Parse the JSON response
    4. Execute the filter on the Pandas DataFrame
    """

    def __init__(self, data_path: str, use_mock: bool = True, api_key: str = None):
        """
        Initialize the agent.

        Args:
            data_path: Path to the adae.csv file
            use_mock: If True, use mock LLM responses instead of OpenAI API
            api_key: OpenAI API key (required if use_mock=False)
        """
        self.df = pd.read_csv(data_path)
        self.use_mock = use_mock
        self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
        # Auto-generate schema from the loaded data and CDISC definitions
        self.schema = build_schema_from_data(self.df)

    def _build_prompt(self, question: str) -> str:
        """Build the LLM prompt from the question and auto-generated schema."""
        return LLM_PROMPT_TEMPLATE.format(
            schema=self.schema,
            question=question
        )

    def _call_llm(self, prompt: str) -> str:
        """
        Call the LLM (real or mock) and return the response.

        Args:
            prompt: The formatted prompt string

        Returns:
            JSON string with target_column and filter_value
        """
        if self.use_mock:
            return self._mock_llm(prompt)
        else:
            return self._call_openai(prompt)

    def _call_openai(self, prompt: str) -> str:
        """
        Call OpenAI API via LangChain.

        Args:
            prompt: The formatted prompt string

        Returns:
            JSON string from the LLM
        """
        try:
            from langchain_openai import ChatOpenAI
            from langchain_core.messages import HumanMessage

            llm = ChatOpenAI(
                model="gpt-4o-mini",
                temperature=0,
                api_key=self.api_key
            )
            response = llm.invoke([HumanMessage(content=prompt)])
            return response.content
        except ImportError:
            raise ImportError(
                "langchain_openai is required for real LLM calls. "
                "Install with: pip install langchain-openai"
            )

    def _mock_llm(self, prompt: str) -> str:
        """
        Mock LLM that uses keyword matching to simulate LLM responses.
        Implements the full Prompt → Parse → Execute flow without an API key.

        The mock extracts the question from the prompt and applies rule-based
        mapping to determine the target column and filter value.

        Args:
            prompt: The formatted prompt string

        Returns:
            JSON string with target_column and filter_value
        """
        # Extract the question from the prompt
        question = prompt.split("Question: ")[-1].split("\n")[0].strip().lower()

        # Severity / intensity mapping
        if any(word in question for word in ["severity", "intense", "intensity",
                                              "severe", "mild", "moderate"]):
            for severity in ["severe", "moderate", "mild"]:
                if severity in question:
                    return json.dumps({
                        "target_column": "AESEV",
                        "filter_value": severity.upper()
                    })
            return json.dumps({"target_column": "AESEV", "filter_value": ""})

        # Serious AE mapping
        if any(word in question for word in COLUMN_SYNONYMS["AESER"]):
            return json.dumps({"target_column": "AESER", "filter_value": "Y"})

        # Relationship / causality mapping
        if any(word in question for word in COLUMN_SYNONYMS["AEREL"]):
            for rel in ["probable", "possible", "none", "remote"]:
                if rel in question:
                    return json.dumps({
                        "target_column": "AEREL",
                        "filter_value": rel.upper()
                    })

        # Outcome mapping
        if any(word in question for word in COLUMN_SYNONYMS["AEOUT"]):
            for outcome in ["recovered", "resolved", "not recovered",
                            "not resolved", "fatal"]:
                if outcome in question:
                    return json.dumps({
                        "target_column": "AEOUT",
                        "filter_value": outcome.upper()
                    })

        # Action taken mapping
        if any(word in question for word in COLUMN_SYNONYMS["AEACN"]):
            for action in ["dose not changed", "drug withdrawn",
                           "dose reduced", "not applicable"]:
                if action in question:
                    return json.dumps({
                        "target_column": "AEACN",
                        "filter_value": action.upper()
                    })

        # Life threatening mapping
        if any(word in question for word in COLUMN_SYNONYMS["AESLIFE"]):
            return json.dumps({"target_column": "AESLIFE", "filter_value": "Y"})

        # Death mapping
        if any(word in question for word in COLUMN_SYNONYMS["AESDTH"]):
            return json.dumps({"target_column": "AESDTH", "filter_value": "Y"})

        # Hospitalization mapping
        if any(word in question for word in COLUMN_SYNONYMS["AESHOSP"]):
            return json.dumps({"target_column": "AESHOSP", "filter_value": "Y"})

        # Body system / organ class mapping
        body_systems = {
            "cardiac": "CARDIAC DISORDERS",
            "skin": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
            "nervous": "NERVOUS SYSTEM DISORDERS",
            "gastrointestinal": "GASTROINTESTINAL DISORDERS",
            "respiratory": "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS",
            "vascular": "VASCULAR DISORDERS",
            "psychiatric": "PSYCHIATRIC DISORDERS",
            "musculoskeletal": "MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS",
            "renal": "RENAL AND URINARY DISORDERS",
            "hepatic": "HEPATOBILIARY DISORDERS",
            "eye": "EYE DISORDERS",
            "ear": "EAR AND LABYRINTH DISORDERS",
            "infection": "INFECTIONS AND INFESTATIONS",
            "metabolism": "METABOLISM AND NUTRITION DISORDERS",
            "blood": "BLOOD AND LYMPHATIC SYSTEM DISORDERS",
            "general": "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
        }
        for keyword, soc_value in body_systems.items():
            if keyword in question:
                return json.dumps({
                    "target_column": "AESOC",
                    "filter_value": soc_value
                })

        # Default: assume the question refers to a specific AE term
        value = self._extract_ae_term(question)
        return json.dumps({"target_column": "AETERM", "filter_value": value})

    def _extract_ae_term(self, question: str) -> str:
        """Extract the AE term from the question by removing filler words and punctuation."""
        # Strip punctuation first
        cleaned = re.sub(r"[?.!,;:]", "", question)
        filler = {"subjects", "patients", "with", "who", "had", "have",
                  "the", "in", "give", "me", "show", "list", "adverse",
                  "events", "aes", "event", "ae", "from", "of", "a", "an",
                  "experienced", "reported", "suffering", "any", "all",
                  "which", "what", "are", "were", "that", "those", "get",
                  "find", "about", "did", "do", "how", "many"}
        words = cleaned.split()
        filtered = [w for w in words if w not in filler]
        return " ".join(filtered).upper().strip()

    def _parse_response(self, response: str) -> dict:
        """
        Parse the LLM response JSON into a dictionary.

        Args:
            response: JSON string from LLM

        Returns:
            Dictionary with target_column and filter_value
        """
        try:
            # Handle cases where LLM wraps JSON in markdown code blocks
            cleaned = response.strip()
            if cleaned.startswith("```"):
                cleaned = re.sub(r"```(?:json)?\s*", "", cleaned)
                cleaned = cleaned.rstrip("`").strip()
            parsed = json.loads(cleaned)

            # Validate required keys
            if "target_column" not in parsed or "filter_value" not in parsed:
                raise ValueError("Response missing required keys")

            return parsed
        except (json.JSONDecodeError, ValueError) as e:
            print(f"Error parsing LLM response: {e}")
            print(f"Raw response: {response}")
            return {"target_column": "", "filter_value": "", "error": str(e)}

    def _execute_query(self, parsed: dict) -> dict:
        """
        Apply the parsed filter to the dataset and return results.

        Uses case-insensitive partial matching via str.contains for flexibility.

        Args:
            parsed: Dictionary with target_column and filter_value

        Returns:
            Dictionary with count and list of matching USUBJIDs
        """
        col = parsed.get("target_column", "")
        val = parsed.get("filter_value", "")

        if not col or not val or col not in self.df.columns:
            return {"count": 0, "subjects": []}

        # Apply filter — case-insensitive partial matching
        mask = self.df[col].astype(str).str.upper().str.contains(
            val.upper(), na=False
        )
        filtered = self.df[mask]

        # Get unique subjects
        subjects = filtered["USUBJID"].unique().tolist()

        return {
            "count": len(subjects),
            "subjects": sorted(subjects)
        }

    def query(self, question: str) -> dict:
        """
        Main entry point: take a natural language question and return results.

        Full flow: Prompt → LLM → Parse → Execute

        Args:
            question: Natural language question about adverse events

        Returns:
            Dictionary with question, parsed filter, count, and subjects
        """
        # Step 1: Build prompt
        prompt = self._build_prompt(question)

        # Step 2: Call LLM (or mock)
        response = self._call_llm(prompt)

        # Step 3: Parse response
        parsed = self._parse_response(response)

        # Step 4: Execute query
        result = self._execute_query(parsed)

        return {
            "question": question,
            "parsed_filter": parsed,
            "count": result["count"],
            "subjects": result["subjects"]
        }

