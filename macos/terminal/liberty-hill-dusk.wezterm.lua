-- Liberty Hill Dusk - WezTerm colour scheme
-- Liberty Hill Studios . macOS port of the Windows Terminal scheme in
-- <repo>/terminal/liberty-hill-dusk.json . palette is byte-identical.
--
-- WHY A .lua MODULE AND NOT A colors/*.toml FILE:
--   WezTerm derives a TOML scheme's NAME from its FILENAME, so a TOML port
--   would have to be named exactly "Liberty Hill Dusk.toml" (with spaces) or
--   `config.color_scheme = 'Liberty Hill Dusk'` silently fails to resolve.
--   A Lua module carries its own name, cannot be broken by a rename, and
--   Lua-defined schemes take precedence over every other source.
--
-- INSTALL:
--     mkdir -p ~/.config/wezterm/colors
--     cp liberty-hill-dusk.wezterm.lua ~/.config/wezterm/colors/
-- then in ~/.config/wezterm/wezterm.lua:
--
--     local wezterm = require 'wezterm'
--     local config  = wezterm.config_builder()
--     local lhs = dofile(wezterm.config_dir .. '/colors/liberty-hill-dusk.wezterm.lua')
--     lhs.apply(config)
--     return config
--
--   `dofile` (not `require`) because the filename contains dots, which Lua's
--   module resolver would read as directory separators.
--
--   If you already define other schemes, pass them through so they survive:
--     lhs.apply(config, { ['My Other Scheme'] = { ... } })
--
--   Or wire it up by hand:
--     config.color_schemes = { [lhs.name] = lhs.scheme }
--     config.color_scheme  = lhs.name
--
-- PALETTE
--   ink-950 #0A0807   parchment #F5ECD9   gold-400 #E8A13A  gold-300 #ECBE5B
--   gold-600 #B3661F  ember-400 #D4542B   ember-300 #E57A53
-- Design law: gold/ember are ACCENTS only - cursor, selection, split lines,
-- scrollbar. Every large surface is ink-950.

local M = {}

M.name = 'Liberty Hill Dusk'

-- Only keys WezTerm documents for a colour scheme appear here. WezTerm
-- validates scheme tables and will complain about unknown keys, so do not
-- add metadata fields inside `M.scheme` - put them on `M` instead.
M.scheme = {
  foreground = '#F5ECD9',
  background = '#0A0807',

  -- gold-400 block cursor with an ink-950 glyph punched through it
  cursor_bg     = '#E8A13A',
  cursor_fg     = '#0A0807',
  cursor_border = '#E8A13A',

  selection_bg = '#4D2C14',
  selection_fg = '#F5ECD9',

  -- thin chrome only; never a filled surface
  scrollbar_thumb = '#6F6557',
  split           = '#B3661F',

  -- normal:  black      red        green      yellow     blue       purple     cyan       white
  ansi = {
    '#1B1612', '#E0604F', '#5FB87A', '#E8A13A',
    '#5AA8E0', '#A878D8', '#7FBFB4', '#CDBFA6',
  },

  -- bright:  black      red        green      yellow     blue       purple     cyan       white
  brights = {
    '#6F6557', '#E57A53', '#83C99B', '#ECBE5B',
    '#7DBDE8', '#C09BE8', '#9AD1C7', '#FDF6E8',
  },
}

--- Register the scheme on `config` and select it.
--- @param config table          the table returned by wezterm.config_builder()
--- @param existing table|nil    any color_schemes you already define, preserved
--- @return table config
function M.apply(config, existing)
  local schemes = existing or {}
  schemes[M.name] = M.scheme
  config.color_schemes = schemes
  config.color_scheme = M.name
  return config
end

return M
