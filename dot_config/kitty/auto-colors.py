"""Give every new tab (including single-tab OS windows) a lasting color.

The shared counter also rotates colors across independent Kitty processes.
Splits and temporary overlays share their tab's color. Colors repeat after
eight new tabs; edit PALETTE to change the backgrounds and tab accents.
"""

import fcntl
import os
from pathlib import Path

from kitty.fast_data_types import patch_color_profiles

# Terminal background, selected-tab background, unselected-tab background.
PALETTE = (
    (0x1E2E46, 0x7AA2F7, 0x354D75),  # blue
    (0x203B2B, 0x9ECE6A, 0x3C5F36),  # green
    (0x362443, 0xBB9AF7, 0x604675),  # purple
    (0x422B20, 0xFF9E64, 0x775036),  # orange
    (0x183B3B, 0x73DACA, 0x326567),  # teal
    (0x40212C, 0xF7768E, 0x743E51),  # rose
    (0x3C351E, 0xE0C46C, 0x6D6032),  # gold
    (0x29333D, 0xA9BBCD, 0x4A5B6C),  # slate
)


def next_colors():
    state_home = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    state_dir = state_home / 'kitty'
    state_dir.mkdir(parents=True, exist_ok=True)
    fd = os.open(state_dir / 'identity-color-counter', os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(fd, 'r+', encoding='ascii') as counter:
        fcntl.flock(counter, fcntl.LOCK_EX)
        try:
            index = int(counter.read() or '0') % len(PALETTE)
        except ValueError:
            index = 0
        counter.seek(0)
        counter.write(str((index + 1) % len(PALETTE)))
        counter.truncate()
        counter.flush()
    return PALETTE[index]


def apply_colors(boss, window, data):
    tab = window.tabref()
    if tab is None:
        return
    colors = getattr(tab, '_identity_colors', None)
    if colors is None:
        # Keep the color when a terminal is detached into a new tab/window.
        colors = getattr(window, '_identity_colors', None) or next_colors()
        tab._identity_colors = colors
    window._identity_colors = colors
    background, active, inactive = colors

    changed = False
    for key, value in (
        ('active_bg', active), ('active_fg', 0x141820),
        ('inactive_bg', inactive), ('inactive_fg', 0xE4E7ED),
    ):
        if getattr(tab, key) != value:
            setattr(tab, key, value)
            changed = True
    if changed:
        tab.mark_tab_bar_dirty()

    if int(window.screen.color_profile.default_bg) != background:
        patch_color_profiles({'background': background}, (), (window.screen.color_profile,), False)
        boss.default_bg_changed_for(window.id)
        window.refresh()


# The initial resize handles every new terminal, including background tabs.
# Focus also restores its identity after a configuration/theme reload.
on_resize = apply_colors
on_focus_change = apply_colors
