local wezterm = require 'wezterm'
local config = {}

config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = 'AlwaysPrompt'

config.color_scheme = 'OneHalfDark'
config.default_cursor_style = 'SteadyBlock'
config.font = wezterm.font('JetBrains Mono', { weight = 'Regular' })
config.font_size = 13

return config
