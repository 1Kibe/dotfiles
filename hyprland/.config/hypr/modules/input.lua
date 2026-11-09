-- Keyboard (ABNT2) and touchpad. The touchpad copies the Windows setup:
-- tap to click, two-finger tap = right click, tap and drag, natural scroll.
hl.config({
  input = {
    -- ABNT2 is the keyboard model, not a variant of "br" (the same as
    -- install.sh's XKB_LAYOUT / XKB_MODEL, and localectl's)
    kb_layout = "br",
    kb_model = "abnt2",
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
