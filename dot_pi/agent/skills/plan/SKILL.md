---
name: plan
description: Creates a clear, actionable implementation plan by inspecting relevant code and documentation without modifying the repository. Use only when explicitly invoked.
disable-model-invocation: true
---

# Plan code changes

Create a clear, actionable implementation plan for the request supplied with this skill command. If no request was supplied, use the clear change request already present in the conversation; if none exists, ask what the user wants to change.

Inspect the relevant code and documentation before planning. Identify affected files, dependencies, risks, edge cases, and appropriate validation or tests. Do not modify source files or implement the plan.
