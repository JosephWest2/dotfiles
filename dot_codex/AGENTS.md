# Global Agent Instructions

- Never use vendor or agent prefixes such as `codex/`, `claude/`, or `t3code/` in Git branch names. Use descriptive, vendor-neutral branch names.
- On the Arch Linux desktop the interactive shell is fish. Give commands the user will type in fish syntax (`for x in a b; ...; end`, `set VAR value`), not bash. Claude Code `!` commands and agent tool shells run bash, so use bash syntax there.
