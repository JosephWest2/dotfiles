---
description: Stage and commit all current changes
argument-hint: "[commit guidance]"
---
Add and commit all current changes in this Git repository.

First inspect `git status --short`, `git diff`, `git diff --cached`, and relevant untracked files. Ensure the changes are coherent and check for accidental secrets, generated artifacts, or unrelated files; stop and ask me if anything looks suspicious. Run relevant quick validation when practical.

Then stage everything with `git add -A` and create one commit with a concise, descriptive commit message that accurately summarizes the changes. ${ARGUMENTS:-Choose the message based on the actual diff.}

Do not amend an existing commit and do not push. If there is nothing to commit, say so. Report the resulting commit hash and message.
