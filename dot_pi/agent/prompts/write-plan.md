---
description: Research a change and save an implementation plan
argument-hint: "<change request>"
---
Create and save a clear, actionable implementation plan for this change:

${ARGUMENTS:-No change request was provided. Ask me what I want to change.}

Read and follow all repository instructions. Inspect the relevant code, tests, and documentation before planning.

Save the finished plan as `.pi/plans/<descriptive-kebab-case-name>.md`, creating the directory if needed. The plan must stand on its own and include:

- The goal, scope, and relevant current behavior
- The proposed approach and key decisions
- Specific files or components expected to change
- Ordered implementation steps with enough detail to execute
- Tests and validation to run
- Risks, edge cases, dependencies, and unresolved questions

Do not implement the planned changes. Only create or update the plan file, then report its path and briefly summarize it.
