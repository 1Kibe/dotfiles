-- Look: borders in the Windows accent color, gaps, rounding, translucent
-- inactive windows, shadow, blur and animations.
-- The VM block in local.lua turns blur and shadow off.
local c = require("modules.colors")

local function rgb(hex)
  local digits = hex:gsub("#", "")
  return "rgb(" .. digits .. ")"
end

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = { colors = { rgb(c.accent_light), rgb(c.accent) }, angle = 45 },
      inactive_border = rgb(c.bg2),
    },
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = {
    rounding = 8,
    -- Same as xfwm4's inactive_opacity (71%) on XFCE
    active_opacity = 1.0,
    inactive_opacity = 0.71,
    shadow = { enabled = true, range = 8, render_power = 3, color = 0xaa1d2021 },
    blur = { enabled = true, size = 4, passes = 2 },
  },
  dwindle = { preserve_split = true },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    -- Plain until the Quickshell wallpaper module; darker than the terminals
    -- (c.bg_hard) so windows stand out
    background_color = rgb(c.bg_deep),
    font_family = "Agave Nerd Font Propo",
  },
  ecosystem = { no_update_news = true, no_donation_nag = true },
  animations = { enabled = true },
})

-- Fast animations: windows pop in, workspaces slide (like the 4-finger swipe)
hl.curve("snappy", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "snappy" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "snappy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "snappy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "linear", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "snappy", style = "slide" })
