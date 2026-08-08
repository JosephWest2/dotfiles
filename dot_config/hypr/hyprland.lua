-- Hyprland configuration.
-- https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output = "DP-1",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1440@120",
    position = "auto-left",
    scale = 1,
    transform = 3,
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "wezterm"
local fileManager = "yazi"
local menu = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    hl.exec_cmd([[gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"]])
    hl.exec_cmd([[gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Dark"]])
    hl.exec_cmd([[gsettings set org.gnome.desktop.interface icon-theme "kora"]])
    hl.exec_cmd("hyprctl setcursor Bibata-Original-Classic 24")
    hl.exec_cmd("waybar")

    hl.exec_cmd("wezterm", { workspace = "name:t silent" })
    hl.exec_cmd("google-chrome-stable", { workspace = "name:b silent" })
    hl.dispatch(hl.dsp.focus({ workspace = "name:t" }))
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require a Hyprland restart and are not applied on-the-fly.
--
-- hl.config({
--     ecosystem = {
--         enforce_permissions = true,
--     },
-- })
-- hl.permission({ binary = "/usr/(bin|local/bin)/grim", type = "screencopy", mode = "allow" })
-- hl.permission({
--     binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
--     type = "screencopy",
--     mode = "allow",
-- })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- See https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 4,
        border_size = 2,
        col = {
            active_border = {
                colors = { "rgba(2244bbcc)", "rgba(33ccffee)" },
                angle = 90,
            },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easeInStrong", { type = "bezier", points = { { 0.88, 0.01 }, { 1, 0.75 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "default", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "default", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "easeInStrong", style = "fade" })

-- "Smart gaps" / "No gaps when only" examples.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding = 0,
-- })
-- hl.window_rule({
--     name = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding = 0,
-- })

hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 1,
        disable_hyprland_logo = true,
        background_color = "0x2e2e2e",
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = -0.4,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Example per-device config retained from the previous configuration.
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "SUPER"

hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd([[hyprpicker | tee >(wl-copy) | { text=$(cat); notify-send "Copied color to clipboard: $text"; echo "$text" | wl-copy --primary; }]]))
hl.bind(mainMod .. " + ALT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + M", hl.dsp.exit())
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + ALT + V", hl.dsp.window.float())
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + ALT + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + ALT + O", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + ALT + SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"))

hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd("~/.config/hypr/scripts/nerd-dictation-toggle.sh"))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region -o ~/Images"))

-- Move focus with mainMod + arrow keys.
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Move windows.
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.swap({ direction = "d" }))

-- Focus, switch to, or move windows to workspaces 1-10.
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.focus({ workspace = i, on_current_monitor = true }))
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Switch to or move windows to case-sensitive letter workspaces a-z and A-Z.
local workspaceLetters = "abcdefghijklmnopqrstuvwxyz"
for i = 1, #workspaceLetters do
    local lowerLetter = workspaceLetters:sub(i, i)
    local upperLetter = lowerLetter:upper()
    local lowerWorkspace = "name:" .. lowerLetter
    local upperWorkspace = "name:" .. upperLetter

    hl.bind(mainMod .. " + " .. lowerLetter, hl.dsp.focus({ workspace = lowerWorkspace }))
    hl.bind(mainMod .. " + SHIFT + " .. upperLetter, hl.dsp.focus({ workspace = upperWorkspace }))
    hl.bind(mainMod .. " + CTRL + " .. lowerLetter, hl.dsp.window.move({ workspace = lowerWorkspace }))
    hl.bind(mainMod .. " + CTRL + SHIFT + " .. upperLetter, hl.dsp.window.move({ workspace = upperWorkspace }))
end

-- Special workspace (scratchpad).
hl.bind(mainMod .. " + ALT + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness.
local mediaBindOptions = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), mediaBindOptions)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), mediaBindOptions)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), mediaBindOptions)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), mediaBindOptions)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), mediaBindOptions)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), mediaBindOptions)

-- Requires playerctl.
local lockedBindOptions = { locked = true }
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), lockedBindOptions)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), lockedBindOptions)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), lockedBindOptions)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), lockedBindOptions)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.workspace_rule({ workspace = "name:b", monitor = "HDMI-A-1", default = true })

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-dragging",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
