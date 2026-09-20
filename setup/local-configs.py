#!/usr/bin/env python3
"""Run after chezmoi apply to connect local entry points to shared defaults."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


def connect(home, setup, name, relative, shared, include):
    target = home / relative
    if not (home / shared).is_file():
        print(f"Missing {home / shared}; apply the shared files first.", file=sys.stderr)
        return False
    existing = target.read_text() if target.exists() else ""
    example = "zshrc.example" if name == "zsh" else "kitty.conf.example"
    if include in existing.splitlines():
        print(f"Already connected: {target}")
        return True
    known = json.loads((setup / "legacy-config-hashes.json").read_text())[name]
    if existing.strip() and hashlib.sha256(existing.encode()).hexdigest() not in known:
        print(
            f"Preserved customized config: {target}\n"
            f"Merge shared preferences manually using {setup / example}; "
            "remove duplicate shared definitions and keep installer/local settings.",
            file=sys.stderr,
        )
        return False
    if target.exists():
        descriptor, backup = tempfile.mkstemp(prefix=target.name + ".before-shared-", dir=target.parent)
        os.close(descriptor)
        shutil.copy2(target, backup)
        print(f"Backup: {backup}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text((setup / example).read_text())
    print(f"Connected: {target}")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home(), help="Destination home (also useful for testing)")
    args = parser.parse_args()
    setup = Path(__file__).resolve().parent
    zsh = connect(args.home, setup, "zsh", ".zshrc", ".config/zsh/shared.zsh",
                  '[[ -r "$HOME/.config/zsh/shared.zsh" ]] && source "$HOME/.config/zsh/shared.zsh"')
    kitty = connect(args.home, setup, "kitty", ".config/kitty/kitty.conf", ".config/kitty/shared.conf",
                    "include shared.conf")
    # The theme picker owns this copy from now on. Never replace an existing theme.
    theme = args.home / ".config/kitty/current-theme.conf"
    default = args.home / ".config/kitty/default-theme.conf"
    if kitty and not theme.exists() and default.is_file():
        shutil.copy2(default, theme)
    return 0 if zsh and kitty else 1


if __name__ == "__main__":
    sys.exit(main())
