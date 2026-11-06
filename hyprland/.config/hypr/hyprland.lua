-- Hyprland config (Lua, Hyprland 0.55+). One module per subject; local.lua
-- (ignored by git) holds machine-specific settings and loads last, so it can
-- override anything. Keybinds and gestures: hyprland/README.md or Super+F1.

-- Any monitor: preferred mode, automatic position and scale.
-- Real monitors and scales go in local.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

require("modules.env")
require("modules.input")
require("modules.keybinds")

-- Optional: a missing local.lua is not an error
pcall(require, "local")
