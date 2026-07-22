local wezterm = require('wezterm')
local config = wezterm.config_builder() 

config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = 'AlwaysPrompt'

config.color_scheme = 'OneHalfDark'
config.default_cursor_style = 'SteadyBlock'
config.font = wezterm.font('CommitMonoNerdFontMono')
config.font_size = 12

config.keys = {}
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = 'ALT',
        action = wezterm.action.ActivateTab(i - 1)
    })
end

return config
