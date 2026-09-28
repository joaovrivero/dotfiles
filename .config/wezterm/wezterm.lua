local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows") ~= nil

local settings = {
    font = wezterm.font("JetBrainsMono Nerd Font"),
    font_size = 18.0,
    -- pinacoteca:begin
    color_scheme = "pinacoteca",
    -- Pinacoteca: palette and provenance in theme/pinacoteca/colors.toml
    color_schemes = {
        pinacoteca = {
            foreground = "#e6ccaf",
            background = "#18130e",
            cursor_bg = "#d7a447",
            cursor_fg = "#18130e",
            cursor_border = "#d7a447",
            selection_bg = "#453b32",
            selection_fg = "#f7e5cf",
            scrollbar_thumb = "#453b32",
            split = "#453b32",
            ansi = { "#2e2822", "#d67066", "#88ab75", "#d7a447", "#799dbb", "#ad8ab6", "#6cabab", "#e6ccaf" },
            brights = { "#7d6b59", "#d67066", "#88ab75", "#d7a447", "#799dbb", "#ad8ab6", "#6cabab", "#f7e5cf" },
            tab_bar = {
                background = "#211c17",
                active_tab = { bg_color = "#d7a447", fg_color = "#18130e", intensity = "Bold" },
                inactive_tab = { bg_color = "#211c17", fg_color = "#b19a80" },
                inactive_tab_hover = { bg_color = "#2e2822", fg_color = "#e6ccaf" },
                new_tab = { bg_color = "#211c17", fg_color = "#7d6b59" },
                new_tab_hover = { bg_color = "#2e2822", fg_color = "#d7a447" },
            },
        },
    },
    -- pinacoteca:end
    window_decorations = " NONE | RESIZE",
    hide_tab_bar_if_only_one_tab = true,
    use_fancy_tab_bar = false,
    tab_bar_at_bottom = true,
    enable_kitty_graphics = true,
    max_fps = 120,
    animation_fps = 1,
    term = "xterm-256color",
    front_end = "OpenGL",
    -- window_background_opacity = 0.9,
    window_padding = {
        left = 20,
        right = 20,
        top = 20,
        bottom = 20,
    },
    keys = {
        { key = "t",   mods = "CTRL",       action = wezterm.action { SpawnTab = "CurrentPaneDomain" } },
        -- Navigate between tabs
        { key = "Tab", mods = "CTRL",       action = wezterm.action { ActivateTabRelative = 1 } },
        { key = "Tab", mods = "CTRL|SHIFT", action = wezterm.action { ActivateTabRelative = -1 } },
        { key = "w",   mods = "CTRL",       action = wezterm.action { CloseCurrentTab = { confirm = true } } },
        { key = "c",   mods = "CTRL",       action = wezterm.action { CopyTo = "Clipboard" } },
        { key = "v",   mods = "CTRL",       action = wezterm.action { PasteFrom = "Clipboard" } },
        { key = "f",   mods = "CTRL",       action = wezterm.action { Search = { CaseInSensitiveString = "" } } },
        -- Split panes
        { key = "s",   mods = "ALT",        action = wezterm.action { SplitHorizontal = { domain = "CurrentPaneDomain" } } },
        { key = "v",   mods = "ALT",        action = wezterm.action { SplitVertical = { domain = "CurrentPaneDomain" } } },
        -- Adjust pane sizes
        { key = "h",   mods = "ALT|SHIFT",  action = wezterm.action { AdjustPaneSize = { "Left", 5 } } },
        { key = "l",   mods = "ALT|SHIFT",  action = wezterm.action { AdjustPaneSize = { "Right", 5 } } },
        { key = "k",   mods = "ALT|SHIFT",  action = wezterm.action { AdjustPaneSize = { "Up", 5 } } },
        { key = "j",   mods = "ALT|SHIFT",  action = wezterm.action { AdjustPaneSize = { "Down", 5 } } },
        -- Navigate between panes
        { key = "h",   mods = "ALT",        action = wezterm.action { ActivatePaneDirection = "Left" } },
        { key = "l",   mods = "ALT",        action = wezterm.action { ActivatePaneDirection = "Right" } },
        { key = "k",   mods = "ALT",        action = wezterm.action { ActivatePaneDirection = "Up" } },
        { key = "j",   mods = "ALT",        action = wezterm.action { ActivatePaneDirection = "Down" } },
        -- Close panes
        { key = "x",   mods = "ALT",        action = wezterm.action { CloseCurrentPane = { confirm = true } } },
    }
}

for key, value in pairs(settings) do
    config[key] = value
end

if is_windows then
    config.default_prog = { "pwsh.exe", "-NoLogo" }
    table.insert(config.keys, 1, {
        key = "w",
        mods = "CTRL|SHIFT",
        action = wezterm.action { SpawnCommandInNewTab = { args = { "wsl.exe", "-d", "Arch", "--cd", "~" } } },
    })
end

-- Machine-specific settings that should not live in the repository:
-- ~/.wezterm.local.lua may return a function that receives and mutates config.
local local_path = wezterm.home_dir .. "/.wezterm.local.lua"
local local_config = loadfile(local_path)
if local_config then
    local ok, apply = pcall(local_config)
    if ok and type(apply) == "function" then
        apply(config)
    end
end

return config
