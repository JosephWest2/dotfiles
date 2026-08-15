---
name: no-edit
description: Enforces read-only repository work for a request stated before or after invocation. Use only when explicitly invoked.
disable-model-invocation: true
---

# Read-only mode

Handle the user's request without modifying the repository.

The request may appear before or after this skill invocation:

- If arguments were supplied with the skill command, treat them as the request.
- Otherwise, use the most recent clear, actionable request in the conversation.
- If no clear request is available, ask the user what they want handled in read-only mode.

You may inspect files, repository state, documentation, and command output. Do not create, edit, delete, rename, format, stage, commit, or otherwise modify repository files.

Prefer commands and tools that are read-only. If fulfilling the request would require repository changes, explain the proposed changes or provide a plan instead of making them.

If files were modified earlier in the conversation, do not revert or alter those changes unless the user explicitly requests it. The read-only restriction applies to all work performed after this skill is invoked.
