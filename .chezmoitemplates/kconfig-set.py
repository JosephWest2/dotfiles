#!/usr/bin/env python3
# chezmoi modify_ helper for KDE rc files: enforce only the listed keys and
# pass every other line through untouched, so KDE keeps owning the rest of the
# file while `chezmoi status` flags drift in these keys. Values are written
# verbatim (no KConfig $HOME expansion).
import sys

def apply(text, settings):
    lines = text.splitlines()
    for group, key, value in settings:
        header = "".join(f"[{g}]" for g in group)
        want = f"{key}={value}"
        try:
            start = lines.index(header)
        except ValueError:
            if lines and lines[-1] != "":
                lines.append("")
            lines += [header, want]
            continue
        end = start + 1
        while end < len(lines) and not lines[end].startswith("["):
            end += 1
        for i in range(start + 1, end):
            if lines[i].split("=", 1)[0] == key:
                lines[i] = want
                break
        else:
            insert = end
            while insert > start + 1 and lines[insert - 1] == "":
                insert -= 1
            lines.insert(insert, want)
    return "\n".join(lines) + "\n"
