# ==============================================================================
# Test Script: 3 example queries against the ClinicalTrialDataAgent
#
# Runs the agent with mock LLM and prints results for each query.
# ==============================================================================

from clinical_data_agent import ClinicalTrialDataAgent

# Initialize agent with mock LLM (no API key needed)
agent = ClinicalTrialDataAgent(
    data_path="question_4_python/adae.csv",
    use_mock=True
)


def print_result(result: dict) -> None:
    """Pretty-print a query result."""
    print("=" * 70)
    print(f"Question: {result['question']}")
    print(f"Parsed filter: {result['parsed_filter']}")
    print(f"Number of subjects: {result['count']}")
    print(f"Subject IDs: {result['subjects']}")
    print("=" * 70)
    print()


# --- Query 1: Severity-based query -------------------------------------------
# Example from the spec
result1 = agent.query(
    "Give me the subjects who had Adverse events of Moderate severity"
)
print_result(result1)

# --- Query 2: Body system query -----------------------------------------------
result2 = agent.query(
    "Which patients experienced cardiac adverse events?"
)
print_result(result2)

# --- Query 3: Specific AE term query ------------------------------------------
result3 = agent.query(
    "Show me subjects who had headache"
)
print_result(result3)
