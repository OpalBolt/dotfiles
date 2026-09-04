local wezterm = require("wezterm")
local config = wezterm.config_builder()

local scheme_path = wezterm.config_dir .. "/colors/matugen_theme.toml"
local f = io.open(scheme_path, "r")
if f then
	f:close()
	config.color_scheme = "matugen_theme"
else
	config.color_scheme = "Builtin Solarized Dark" -- any built-in scheme name you like as a placeholder
end

-- Everything non-color lives here as normal, untouched by theme swaps
config.font = wezterm.font("JetBrains Mono")
config.font_size = 11
config.window_background_opacity = 0.75
config.wayland_window_background_blur = true
config.enable_tab_bar = false
config.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }

return config
