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
  -- Runs first: the polkit agent and the idle daemon (hypridle.conf; the
  -- drop-in in ~/.config/systemd/user brings it back if it stops) start
  -- through systemd
  hl.exec_cmd("dbus-update-activation-environment --systemd " .. table.concat(session_env, " ")
    .. " && systemctl --user start hyprpolkitagent hypridle")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  -- Images through hypr-clip-imagem: Configurações can turn them off
  hl.exec_cmd("wl-paste --type image --watch hypr-clip-imagem")

  -- GTK apps read these (no xsettings outside XFCE); GTK4 also through the portal
  local cmds = {}
  for _, setting in ipairs(gtk) do
    table.insert(cmds, "gsettings set org.gnome.desktop.interface " .. setting)
  end
  hl.exec_cmd(table.concat(cmds, "; "))

  -- "test", not "[ ]": Hyprland reads a leading "[...]" as window rules
  hl.exec_cmd('test -f "$HOME/.config/quickshell/shell.qml" && qs')

  -- Iniciar com o sistema (Configurações → Apps padrão), only at login,
  -- never on a reload. dotfiles_autostart.lua (ids only, out of git) says
  -- whether the ArtCraft Launcher starts (hidden, no window: the bar has no
  -- tray; a fixed command, "command -v" only checks it is installed) and
  -- which apps open, each one checked and opened by actions.lua's launcher,
  -- 16 at most. Without the file: the ArtCraft Launcher only
  local actions = require("modules.actions")
  local start = actions.data_file("dotfiles_autostart") or { artcraft = true, apps = {} }
  if start.artcraft ~= false then
    hl.exec_cmd("command -v artcraft-launcher >/dev/null && artcraft-launcher --hidden")
  end
  for i, id in ipairs(type(start.apps) == "table" and start.apps or {}) do
    if i > 16 then
      break
    end
    local cmd = actions.app_command(id)
    if cmd then
      hl.exec_cmd(cmd)
    end
  end
end)
