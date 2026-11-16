-- Action name -> command. Keybinds and gestures only use these names, so
-- moving an action to a Quickshell module means changing one line here.
-- Quickshell modules expose `IpcHandler { target: "<name>" }` with the
-- function used below; until a module exists its command fails quietly.
local function qs(target, fn)
  return "qs ipc call " .. target .. " " .. (fn or "toggle")
end

-- An app chosen in Configurações (Apps padrão, Iniciar com o sistema) is only
-- an id of a .desktop file: checked here again (the shell's pattern), it must
-- be a file directly in one of the applications folders, and it is opened by
-- a fixed launcher (uwsm when the session runs under it, else gtk-launch),
-- never by a command line from the settings. The launcher runs the Exec of
-- the .desktop file that GIO finds for that id. Anything else: nil, and the
-- caller keeps its own.
local function app_folders()
  local home = os.getenv("HOME") or ""
  local data_home = os.getenv("XDG_DATA_HOME") or (home .. "/.local/share")
  local out = { data_home .. "/applications" }
  for dir in string.gmatch(os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share", "[^:]+") do
    if dir:sub(1, 1) == "/" and not dir:find("..", 1, true) then
      table.insert(out, dir .. "/applications")
    end
  end
  table.insert(out, data_home .. "/flatpak/exports/share/applications")
  table.insert(out, "/var/lib/flatpak/exports/share/applications")
  return out
end
local function app_command(id)
  if type(id) ~= "string" or #id > 104 or not id:match("^[A-Za-z0-9][A-Za-z0-9._-]*%.desktop$") then
    return nil
  end
  for _, dir in ipairs(app_folders()) do
    -- A file that can be read: a folder opens but gives no byte
    local f = io.open(dir .. "/" .. id, "rb")
    if f then
      local byte = f:read(1)
      f:close()
      if byte then
        return "uwsm check is-active && exec uwsm app -- '" .. id .. "' || exec gtk-launch '" .. id .. "'"
      end
    end
  end
  return nil
end

-- A data file the shell writes next to this config (ids only, out of git):
-- read from that exact path, in the config's folder as hyprland.lua found it
-- (dotfiles_config_dir; never through package.path, which also looks in the
-- current folder), as text only and with an empty environment, so it can
-- only build a table of plain values. Anything else: nil
local function data_file(name)
  local dir = dotfiles_config_dir
  if type(dir) ~= "string" or dir:sub(1, 1) ~= "/" then
    return nil
  end
  local chunk = loadfile(dir .. "/" .. name .. ".lua", "t", {})
  if not chunk then
    return nil
  end
  local ok, data = pcall(chunk)
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

-- The terminal and the file manager of Super+Enter and Super+E: the shell's
-- choice (dotfiles_apps.lua), else Kitty and Thunar
local chosen = data_file("dotfiles_apps") or {}

return {
  -- For autostart.lua: the same check, launcher and data reading
  app_command   = app_command,
  data_file     = data_file,

  -- Shell (Quickshell modules)
  -- Temporary, until each Quickshell module exists: rofi
  launcher      = "rofi -show drun",
  clipboard     = qs("clipboard"),
  notifications = qs("notifications"),
  controlcenter = qs("controlcenter"),
  powermenu     = qs("powermenu"),
  taskmanager   = qs("taskmanager"),   -- system panel; btop is in its footer
  settings      = qs("settings"),      -- Configurações, on the left edge
  capture       = qs("capture", "open"),   -- Print: capture bar
  capture_ocr   = qs("capture", "ocr"),    -- text of an area to the clipboard
  capture_record = qs("capture", "record"), -- record the screen / stop
  overview      = qs("overview"),
  -- Waits for the compositor to confirm the lock (also used by hypridle)
  lock          = "hypr-travar",

  -- Apps and tools (until a Quickshell module replaces them)
  cheatsheet    = "kitty --class hypr-atalhos hypr-atalhos",
  terminal      = app_command(chosen.terminal) or "kitty",
  files         = app_command(chosen.files) or "thunar",
  calculator    = "hypr-calculadora",   -- Qalculate with the look of the dotfiles
  print_tela    = "hypr-print tela",
  print_area    = "hypr-print area",
  print_janela  = "hypr-print janela",
  -- Floats smaller and centered in the free area / back to the tiling
  float         = "hypr-flutuar",
  -- uwsm session: stop it cleanly; the "Hyprland" entry without uwsm: exit
  logout        = "uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'",

  -- Media keys (the Quickshell OSD reads PipeWire and brightness itself)
  volume_up       = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
  volume_down     = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
  volume_mute     = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  mic_mute        = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
  brightness_up   = "brightnessctl -e4 -n2 set 5%+",
  brightness_down = "brightnessctl -e4 -n2 set 5%-",
  media_play      = "playerctl play-pause",
  media_next      = "playerctl next",
  media_prev      = "playerctl previous",
}
