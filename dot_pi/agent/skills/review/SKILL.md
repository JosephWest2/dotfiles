---
name: review
description: Reviews current Git changes for bugs, regressions, security issues, edge cases, and inadequate tests. Use only when explicitly invoked.
disable-model-invocation: true
---

# Review current changes

Review the current code changes in this repository. Use `git status --short`, `git diff`, and `git diff --cached` so both unstaged and staged changes are covered; inspect relevant untracked files too.

Focus especially on bugs, regressions, security issues, incorrect assumptions, missing edge cases, and inadequate tests. Apply any focus supplied with the skill command; otherwise, also assess whether the changes fit the surrounding code and repository conventions.

Do not modify files. Report findings first, ordered by severity, with precise file and line references. Explain the impact and a concrete fix. If there are no findings, say so and mention any remaining risks or validation gaps.
