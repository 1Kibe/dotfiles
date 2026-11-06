-- Environment for the session and the apps it starts.
local home = os.getenv("HOME")

-- Scripts of this repo (hypr-print, hypr-atalhos) live in ~/.local/bin
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))

-- Cursor (same as XFCE and the login screen)
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic-Right")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Native Wayland for Qt and Electron apps, X11 as fallback
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
