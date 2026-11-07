-- Action name -> command. Keybinds and gestures only use these names, so
-- moving an action to a Quickshell module means changing one line here.
-- Quickshell modules expose `IpcHandler { target: "<name>" }` with the
-- function used below; until a module exists its command fails quietly.
local function qs(target, fn)
  return "qs ipc call " .. target .. " " .. (fn or "toggle")
end

return {
  -- Shell (Quickshell modules)
  -- Temporary, until each Quickshell module exists: rofi
  launcher      = "rofi -show drun",
  clipboard     = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy",
  notifications = qs("notifications"),
  controlcenter = qs("controlcenter"),
  powermenu     = qs("powermenu"),
  overview      = qs("overview"),
  lock          = qs("lock", "lock"),

  -- Apps and tools (until a Quickshell module replaces them)
  cheatsheet    = "alacritty --class hypr-atalhos -e hypr-atalhos",
  taskmanager   = "alacritty --class btop -e btop",
  terminal      = "alacritty",
  files         = "thunar",
  print_tela    = "hypr-print tela",
  print_area    = "hypr-print area",
  print_janela  = "hypr-print janela",
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
