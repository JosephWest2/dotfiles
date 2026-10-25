# /tmp is a RAM-backed tmpfs here; keep Claude Code's scratchpads on disk.
# systemd-tmpfiles cleans /var/tmp after 30 days.
set --export CLAUDE_CODE_TMPDIR /var/tmp
