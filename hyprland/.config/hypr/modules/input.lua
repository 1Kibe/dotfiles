-- Keyboard (ABNT2) and touchpad. The touchpad copies the Windows setup:
-- tap to click, two-finger tap = right click, tap and drag, natural scroll.
hl.config({
  input = {
    kb_layout = "br",
    kb_variant = "abnt2",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      tap_to_click = true,
      tap_and_drag = true,
      natural_scroll = true,
      disable_while_typing = true,
      clickfinger_behavior = false,
    },
  },
})
