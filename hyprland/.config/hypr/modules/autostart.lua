-- Started once with the session. The shell (Quickshell) only starts when it
-- has a config, so a fresh install shows no errors.
local gtk = {
  "gtk-theme 'Adwaita-dark'",
  "color-scheme 'prefer-dark'",
  "icon-theme 'breeze-dark'",
  "font-name 'Agave Nerd Font Propo 11'",
  "cursor-theme 'Bibata-Modern-Classic-Right'",
  "cursor-size 24",
}

-- Variables set with hl.env (env.lua, local.lua) only reach apps started by
-- Hyprland. Copy them to systemd and D-Bus too, so apps they start (file
-- manager windows, portals, the polkit agent) get the same cursor and
-- toolkit settings. Names that are not set are skipped.
local session_env = {
  "XCURSOR_THEME", "XCURSOR_SIZE", "HYPRCURSOR_SIZE",
  "QT_QPA_PLATFORM", "QT_WAYLAND_DISABLE_WINDOWDECORATION",
  "ELECTRON_OZONE_PLATFORM_HINT", "LIBGL_ALWAYS_SOFTWARE",
}

hl.on("hyprland.start", function()
  -- Runs first: the polkit agent below starts through systemd
  hl.exec_cmd("dbus-update-activation-environment --systemd " .. table.concat(session_env, " ")
    .. " && systemctl --user start hyprpolkitagent")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- GTK apps read these (no xsettings outside XFCE); GTK4 also through the portal
  local cmds = {}
  for _, setting in ipairs(gtk) do
    table.insert(cmds, "gsettings set org.gnome.desktop.interface " .. setting)
  end
  hl.exec_cmd(table.concat(cmds, "; "))

  hl.exec_cmd('[ -f "$HOME/.config/quickshell/shell.qml" ] && qs')
end)
