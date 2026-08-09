---
description: Implement a saved plan from .pi/plans
argument-hint: "[plan-file]"
---
Implement the saved plan specified here:

${ARGUMENTS:-Use the relevant plan in `.pi/plans/`. If there are zero or multiple plausible plans, ask me which plan to use.}

Read the complete plan and all repository instructions before editing. Inspect the current code to determine how the plan applies to the repository's current state.

Implement the plan end to end using focused, maintainable changes that fit existing conventions. Add or update meaningful tests where appropriate and run the most relevant available checks. Do not commit or push unless I explicitly ask. Report the files changed, validation results, and any deviations from or unfinished parts of the plan.
