-- Windows that float: tools opened by keybinds, dialogs and pickers.
hl.window_rule({
  name = "float-btop",
  match = { class = "^(btop)$" },
  float = true,
  size = { "monitor_w * 0.6", "monitor_h * 0.65" },
  center = true,
})
hl.window_rule({
  name = "float-hypr-atalhos",
  match = { class = "^(hypr-atalhos)$" },
  float = true,
  size = { "monitor_w * 0.55", "monitor_h * 0.75" },
  center = true,
})
hl.window_rule({
  name = "float-qalculate",
  match = { class = "^(qalculate-gtk)$" },
  float = true,
  center = true,
})
hl.window_rule({
  name = "float-nmtui",
  match = { class = "^(nmtui)$" },
  float = true,
  size = { "monitor_w * 0.5", "monitor_h * 0.6" },
  center = true,
})
hl.window_rule({
  name = "float-bluetui",
  match = { class = "^(bluetui)$" },
  float = true,
  size = { "monitor_w * 0.5", "monitor_h * 0.6" },
  center = true,
})
hl.window_rule({
  name = "float-nm-connection-editor",
  match = { class = "^(nm-connection-editor)$" },
  float = true,
  size = { "monitor_w * 0.6", "monitor_h * 0.7" },
  center = true,
})
hl.window_rule({
  name = "float-polkit",
  match = { class = "^(hyprpolkitagent)$" },
  float = true,
  center = true,
})
hl.window_rule({
  name = "float-file-picker",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float = true,
  center = true,
})
hl.window_rule({
  name = "float-pavucontrol",
  match = { class = "^(org.pulseaudio.pavucontrol)$" },
  float = true,
})

-- From Hyprland's example config: apps can't maximize themselves (tiling
-- decides), and XWayland drag helpers don't take focus
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})
hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- Glass bar: Hyprland blurs what is behind the Quickshell bar and its
-- tooltips; fully transparent pixels between the islands stay sharp.
hl.layer_rule({
  name = "glass-quickshell-bar",
  match = { namespace = "^(quickshell-bar)$" },
  blur = true,
  blur_popups = true,
  ignore_alpha = 0.1,
})
