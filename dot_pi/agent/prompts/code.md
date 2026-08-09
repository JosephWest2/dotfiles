---
description: Implement a coding task using my guidelines
argument-hint: "[task]"
---
Implement the following coding task:

${ARGUMENTS:-Use the task already described in the conversation. If there is no clear task, ask me what to implement.}

Follow these coding guidelines:

- Read and follow all repository instructions before editing.
- Inspect the relevant code and tests first; do not assume my diagnosis is correct.
- Prefer focused, maintainable changes that match existing conventions.
- Ask before making significant tradeoffs or expanding the scope.
- Add or update meaningful tests when appropriate.
- Run the most relevant available checks and report the results.
- Do not commit or push changes unless I explicitly ask.
