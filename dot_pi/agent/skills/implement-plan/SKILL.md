---
name: implement-plan
description: Implements a saved plan from .pi/plans end to end, including appropriate tests and validation. Use only when explicitly invoked.
disable-model-invocation: true
---

# Implement a saved plan

Implement the saved plan identified by arguments supplied with this skill command. If no plan was identified, use the relevant plan in `.pi/plans/`. If there are zero or multiple plausible plans, ask which plan to use.

Read the complete plan and all repository instructions before editing. Inspect the current code to determine how the plan applies to the repository's current state.

Implement the plan end to end using focused, maintainable changes that fit existing conventions. Add or update meaningful tests where appropriate and run the most relevant available checks. Do not commit or push unless the user explicitly asks. Report the files changed, validation results, and any deviations from or unfinished parts of the plan.
