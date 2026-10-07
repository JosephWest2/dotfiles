{{- $remote := "MacBook Air" -}}
{{- $remoteOS := "macOS, arm64" -}}
{{- $remoteHost := "josephs-macbook-air" -}}
{{- $local := "Arch Linux desktop" -}}
{{- if eq .chezmoi.os "darwin" -}}
{{- $remote = "Arch Linux desktop" -}}
{{- $remoteOS = "Arch Linux, x86_64" -}}
{{- $remoteHost = "joeyarchlinux" -}}
{{- $local = "MacBook Air" -}}
{{- end -}}
---
name: tailnet-ssh
description: SSH into the user's other personal machine, the {{ $remote }} ({{ $remoteOS }}), over Tailscale at tailnet host `{{ $remoteHost }}`. Use when the user wants something done or checked on their Mac, MacBook, Linux box, Arch desktop, or "the other machine".
---

# Other machine over Tailscale

This is the user's **{{ $local }}**. The other machine is the **{{ $remote }}** ({{ $remoteOS }}):
`josephwest@{{ $remoteHost }}`, OpenSSH with key `~/.ssh/tailnet_ed25519`. The key is only
accepted from tailnet addresses.

Helper `{{ .skillDir }}/scripts/tailnet.sh` (`--help` for details):

- `check`: diagnose reachability and auth.
- `run '<cmd>'`: run a command on the remote. Stdin passes through, and the exit code propagates.
- `rsync ... remote:PATH`: rsync with the right ssh options; `remote:` is the remote home.
- `ssh [opts] [-- cmd]`: e.g. `-t` for a TTY, or `-N -L` for a tunnel.
- `target`: print `user@host`.

Things you'd otherwise have to discover:

- Both login shells are **fish**, and non-login sessions lack Homebrew and other PATH entries.
  `run` executes the command with **bash** under a login shell, so write bash. Raw `ssh host cmd`
  gets fish and a short PATH.
- macOS has **bash 3.2** and **openrsync**, not GNU rsync.
- The MacBook is often asleep or offline. If `check` can't reach it, tell the user.
- Setup, if it ever needs redoing: each machine's `tailnet_ed25519.pub` goes in the other's
  `authorized_keys` with `from="100.64.0.0/10,fd7a:115c:a1e0::/48"`, plus a `known_hosts`
  entry for the short hostname. Tailscale SSH must stay **off** on Linux, or tailscaled takes
  port 22 on the tailnet and ignores keys.
