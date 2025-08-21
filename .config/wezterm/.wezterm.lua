local wezterm = require 'wezterm'
local config = wezterm.config_builder() 

config = {
  font = wezterm.font("JetBrainsMono Nerd Font"),
  font_size = 14.0,
  color_scheme = "Kanagawa (Gogh)",
  default_prog = {"pwsh.exe", "-NoLogo"},
  -- window_decorations = " NONE | RESIZE",
  hide_tab_bar_if_only_one_tab = true,
  enable_kitty_graphics = true,
  max_fps = 120,
  animation_fps = 1,
  term = "xterm-256color",
  front_end = "OpenGL",
  window_background_opacity = 0.9,
  window_padding = {
    left = 15,
    right = 15,
    top = 15,
    bottom = 15,
  },
  keys = {
    {key="w", mods="CTRL|SHIFT", action=wezterm.action{SpawnCommandInNewTab={args={"wsl.exe", "-d", "Arch", "--cd", "~"}}}},
    {key="t", mods="CTRL", action=wezterm.action{SpawnTab="CurrentPaneDomain"}},
        -- Navigate between tabs
        {key="Tab", mods="CTRL", action=wezterm.action{ActivateTabRelative=1}},
        {key="Tab", mods="CTRL|SHIFT", action=wezterm.action{ActivateTabRelative=-1}},
    {key="w", mods="CTRL", action=wezterm.action{CloseCurrentTab={confirm=true}}},
    {key="c", mods="CTRL", action=wezterm.action{CopyTo="Clipboard"}},
    {key="v", mods="CTRL", action=wezterm.action{PasteFrom="Clipboard"}},
    {key="f", mods="CTRL", action=wezterm.action{Search={CaseInSensitiveString=""}}},
    -- Split panes
    {key="s", mods="ALT", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    {key="v", mods="ALT", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    -- Adjust pane sizes
    {key="h", mods="ALT|SHIFT", action=wezterm.action{AdjustPaneSize={"Left", 5}}},
    {key="l", mods="ALT|SHIFT", action=wezterm.action{AdjustPaneSize={"Right", 5}}},
    {key="k", mods="ALT|SHIFT", action=wezterm.action{AdjustPaneSize={"Up", 5}}},
    {key="j", mods="ALT|SHIFT", action=wezterm.action{AdjustPaneSize={"Down", 5}}},
    -- Navigate between panes
    {key="h", mods="ALT", action=wezterm.action{ActivatePaneDirection="Left"}},
    {key="l", mods="ALT", action=wezterm.action{ActivatePaneDirection="Right"}},
    {key="k", mods="ALT", action=wezterm.action{ActivatePaneDirection="Up"}},
    {key="j", mods="ALT", action=wezterm.action{ActivatePaneDirection="Down"}},
    -- Close panes
    {key="x", mods="ALT", action=wezterm.action{CloseCurrentPane={confirm=true}}},
  }
}

return config