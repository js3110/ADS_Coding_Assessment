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
# Describes the dataset structure so the LLM understands what columns exist
# and how to map natural language concepts to column names.

DATASET_SCHEMA = """
The dataset contains adverse event (AE) records from a clinical trial.
Each row represents one adverse event for one subject.

Key columns:
- USUBJID: Unique subject identifier
- AETERM: Reported term for the adverse event (e.g., "HEADACHE", "NAUSEA")
- AEDECOD: Dictionary-derived term (coded preferred term)
- AEBODSYS: Body system or organ class (e.g., "NERVOUS SYSTEM DISORDERS")
- AESOC: Primary system organ class (e.g., "CARDIAC DISORDERS", "SKIN AND SUBCUTANEOUS TISSUE DISORDERS")
- AESEV: Severity/intensity of the AE. Values: "MILD", "MODERATE", "SEVERE"
- AESER: Serious adverse event flag. Values: "Y" or "N"
- AEREL: Causality/relationship to treatment (e.g., "PROBABLE", "POSSIBLE", "NONE")
- AEACN: Action taken with study treatment
- AEOUT: Outcome of adverse event

Column mapping guide:
- "severity" or "intensity" → AESEV
- "serious" → AESER
- "body system" or "organ class" → AEBODSYS or AESOC
- Specific condition names (e.g., "Headache") → AETERM
- "relationship" or "causality" → AEREL
"""

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

    def _build_prompt(self, question: str) -> str:
        """Build the LLM prompt from the question and schema."""
        return LLM_PROMPT_TEMPLATE.format(
            schema=DATASET_SCHEMA,
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
        if "serious" in question:
            return json.dumps({"target_column": "AESER", "filter_value": "Y"})

        # Relationship / causality mapping
        if any(word in question for word in ["relationship", "causality",
                                              "related", "causally"]):
            for rel in ["probable", "possible", "none", "remote"]:
                if rel in question:
                    return json.dumps({
                        "target_column": "AEREL",
                        "filter_value": rel.upper()
                    })

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
        """Extract the AE term from the question by removing filler words."""
        filler = {"subjects", "patients", "with", "who", "had", "have",
                  "the", "in", "give", "me", "show", "list", "adverse",
                  "events", "aes", "event", "ae", "from", "of", "a", "an",
                  "experienced", "reported", "suffering", "any", "all",
                  "which", "what", "are", "were", "that", "those", "get",
                  "find", "about", "did", "do", "how", "many"}
        words = question.split()
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
