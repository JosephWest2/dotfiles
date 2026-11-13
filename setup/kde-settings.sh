#!/usr/bin/env bash
# Seed the KDE Plasma settings chosen on joeyarchlinux.
#
# KDE rewrites its rc files constantly (window geometry, shortcut registrations,
# per-install UUIDs), so chezmoi does not manage them. This script writes only
# the deliberate choices and never runs automatically: run it once on a fresh
# install, or after editing it. Settings changed later in System Settings stay
# as they are until this script is run again. kglobalaccel can re-save
# shortcuts it holds in memory, so on a fresh install run this from a TTY
# before the first Plasma login (or log out right after running it).
#
#   bash setup/kde-settings.sh      # then log out and back in for shortcuts
set -euo pipefail

command -v kwriteconfig6 >/dev/null || { echo "kwriteconfig6 not found; is this KDE Plasma 6?" >&2; exit 1; }
kw() { kwriteconfig6 "$@"; }
TAB=$'\t'

# Global shortcuts. Values are "active,default,description"; tab separates
# multiple keys. Vim-style focus switching takes Meta+H/J/K/L, so Lock Session
# loses Meta+L, and Meta+Q moves from the activity switcher to Close Window.
sc() { kw --file kglobalshortcutsrc --group "$1" --key "$2" "$3"; }
sc kwin "Overview"            "Meta,Meta+W,Toggle Overview"
sc kwin "Window Close"        "Meta+Q,Alt+F4,Close Window"
sc kwin "Window Fullscreen"   "Meta+M,none,Make Window Fullscreen"
sc kwin "MoveMouseToFocus"    "Meta+C${TAB}Meta+F5,Meta+F5,Center Pointer in Focused Window"
sc kwin "Switch Window Left"  "Meta+H${TAB}Meta+Alt+Left,Meta+Alt+Left,Switch to Window to the Left"
sc kwin "Switch Window Down"  "Meta+J${TAB}Meta+Alt+Down,Meta+Alt+Down,Switch to Window Below"
sc kwin "Switch Window Up"    "Meta+K${TAB}Meta+Alt+Up,Meta+Alt+Up,Switch to Window Above"
sc kwin "Switch Window Right" "Meta+L${TAB}Meta+Alt+Right,Meta+Alt+Right,Switch to Window to the Right"
sc ksmserver "Lock Session"   "Screensaver,Screensaver${TAB}Meta+L,Lock Session"
sc plasmashell "activate application launcher" "Alt+F1,Meta${TAB}Alt+F1,Activate Application Launcher"
sc plasmashell "manage activities"  "none,Meta+Q,Show Activity Switcher"
sc plasmashell "next activity"      "Meta+A,none,Walk through activities"
sc plasmashell "previous activity"  "Meta+Shift+A,none,Walk through activities (Reverse)"

# Window manager: focus follows mouse, no top-left hot corner, no sticky
# screen edges between monitors, virtual desktops only on the primary screen.
kw --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse
kw --file kwinrc --group Effect-overview --key BorderActivate 9
kw --file kwinrc --group EdgeBarrier --key EdgeBarrier 0
kw --file kwinrc --group Plugins --key virtualdesktopsonlyonprimaryEnabled true

# Look and feel, default terminal, file dialog.
if command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop >/dev/null || true
fi
if command -v ghostty >/dev/null; then
    kw --file kdeglobals --group General --key TerminalApplication "$(command -v ghostty) --gtk-single-instance=true"
    kw --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop
fi
kw --file kdeglobals --group "KFileDialog Settings" --key "Sort by" Date
kw --file kdeglobals --group "KFileDialog Settings" --key "View Style" DetailTree

# Lock the screen after 10 min. (No auto-suspend and the display timeout are
# enforced by chezmoi's modify_powerdevilrc, because silent drift there breaks
# SSH and long-running jobs.)
kw --file kscreenlockerrc --group Daemon --key Timeout 10

# Endgame Gear OP1 8k mouse: flat acceleration profile, +0.4 speed.
kw --file kcminputrc --group Libinput --group 13159 --group 6500 \
   --group "Endgame Gear Endgame Gear OP1 8k Gaming Mouse" --key PointerAccelerationProfile 1
kw --file kcminputrc --group Libinput --group 13159 --group 6500 \
   --group "Endgame Gear Endgame Gear OP1 8k Gaming Mouse" --key PointerAcceleration 0.400

# No splash screen; no browser-integration nag; no removable-media automount.
kw --file ksplashrc --group KSplash --key Engine none
kw --file ksplashrc --group KSplash --key Theme None
kw --file kded5rc --group Module-browserintegrationreminder --key autoload false
kw --file kded5rc --group Module-device_automounter --key autoload false

# Baloo's settings are enforced by chezmoi's modify_baloofilerc.

if command -v qdbus6 >/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi
echo "KDE settings written. Log out and back in to apply shortcuts and input settings."
