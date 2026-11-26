-- Keybinds and touchpad gestures. Every bind has a description
-- "<Group>: <text>" (groups: Sistema, Janelas, Áreas, Mídia): it is what
-- hypr-atalhos (Super+F1) and hyprland/README.md show. Commands live in
-- actions.lua; here only keys -> actions.
local a = require("modules.actions")
local areas = require("modules.areas")

-- Runs an action from actions.lua
local function run(keys, action, description, flags)
  flags = flags or {}
  flags.description = description
  hl.bind(keys, hl.dsp.exec_cmd(a[action]), flags)
end

-- Runs a Hyprland dispatcher or a Lua function
local function bind(keys, dispatcher, description, flags)
  flags = flags or {}
  flags.description = description
  hl.bind(keys, dispatcher, flags)
end

-- Alt+Tab style: focus the next/previous window and bring it to the front
local function cycle(previous)
  return function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = not previous }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
  end
end

-- Gesture helper: a function that runs an action from actions.lua, only
-- with the session unlocked. Hyprland runs gestures over the lock screen
-- (a key bind runs there only with locked = true), so hypr-destravado asks
-- the compositor first; when in doubt nothing runs.
local function launch(action)
  return function()
    hl.dispatch(hl.dsp.exec_cmd("hypr-destravado && (" .. a[action] .. ")"))
  end
end

-- ── Sistema ─────────────────────────────────────────────────────────────────
run("Super_L", "launcher", "Sistema: Abrir o launcher", { release = true })
run("SUPER + D", "launcher", "Sistema: Abrir o launcher")
run("SUPER + R", "launcher", "Sistema: Abrir o launcher")
-- Copilot key of the Yoga: sends Shift+Super+F23 (keysym XF86Assistant)
run("SUPER + SHIFT + XF86Assistant", "launcher", "Sistema: Abrir o lançador (tecla Copilot)")
run("SUPER + space", "terminal", "Sistema: Abrir o terminal")
run("SUPER + Return", "terminal", "Sistema: Abrir o terminal")
run("SUPER + E", "files", "Sistema: Abrir o Thunar")
run("SUPER + L", "lock", "Sistema: Travar a tela")
-- Lid closed: lock, also with a monitor plugged in (logind does not sleep
-- then, so hypridle's lock before sleeping never runs). "Lid Switch" is the
-- usual kernel name (hyprctl devices, Switches); on a machine without it the
-- bind just never fires. Another name: add the same bind in local.lua.
run("switch:on:Lid Switch", "lock", "Sistema: Travar ao fechar a tampa", { locked = true })
run("SUPER + V", "clipboard", "Sistema: Histórico do clipboard")
run("SUPER + N", "notifications", "Sistema: Central de notificações")
run("SUPER + A", "controlcenter", "Sistema: Central de controle")
-- Gear key (F9) of the Yoga sends Super+I
run("SUPER + I", "controlcenter", "Sistema: Central de controle (tecla engrenagem)")
run("SUPER + X", "powermenu", "Sistema: Energia (central de controle)")
run("SUPER + S", "settings", "Sistema: Configurações")
run("CTRL + ALT + Delete", "powermenu", "Sistema: Energia (central de controle)")
run("SUPER + Tab", "overview", "Sistema: Visão geral das janelas")
run("SUPER + F1", "cheatsheet", "Sistema: Lista de atalhos")
run("CTRL + SHIFT + Escape", "taskmanager", "Sistema: Monitor do sistema (processos)")
run("Print", "capture", "Sistema: Captura de tela (área, janela ou tela, com anotação)")
run("SHIFT + Print", "print_tela", "Sistema: Print da tela inteira")
run("SUPER + SHIFT + S", "print_area", "Sistema: Print de uma área")
run("ALT + Print", "print_janela", "Sistema: Print da janela ativa")
run("SUPER + SHIFT + O", "capture_ocr", "Sistema: Copiar o texto de uma área (OCR)")
run("SUPER + T", "profiles", "Sistema: Trocar de perfil")
run("SUPER + SHIFT + T", "profile_next", "Sistema: Próximo perfil")
run("SUPER + ALT + R", "capture_record", "Sistema: Gravar a tela / parar a gravação")
run("XF86Calculator", "calculator", "Sistema: Calculadora")
bind("SUPER + SHIFT + R", hl.dsp.reload_config(), "Sistema: Recarregar a config do Hyprland")
run("SUPER + SHIFT + Escape", "logout", "Sistema: Sair da sessão (emergência, sem confirmação)")

-- ── Janelas ─────────────────────────────────────────────────────────────────
bind("ALT + F4", hl.dsp.window.close(), "Janelas: Fechar")
bind("SUPER + Q", hl.dsp.window.close(), "Janelas: Fechar")
bind("SUPER + left", hl.dsp.window.swap({ direction = "left" }), "Janelas: Trocar de lugar com a da esquerda")
bind("SUPER + right", hl.dsp.window.swap({ direction = "right" }), "Janelas: Trocar de lugar com a da direita")
bind("SUPER + up", hl.dsp.window.fullscreen({ action = "set", mode = "maximized" }), "Janelas: Maximizar")
bind("SUPER + down", hl.dsp.window.fullscreen({ action = "unset", mode = "maximized" }), "Janelas: Restaurar")
run("SUPER + F", "float", "Janelas: Flutuar menor e centralizada / voltar ao mosaico")
run("SUPER + H", "minimize", "Janelas: Minimizar")
run("SUPER + SHIFT + H", "restore_last", "Janelas: Trazer a última minimizada")
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }), "Janelas: Tela cheia")
bind("SUPER + J", hl.dsp.layout("togglesplit"), "Janelas: Alternar divisão horizontal/vertical") -- dwindle only
bind("ALT + Tab", cycle(false), "Janelas: Próxima janela")
bind("ALT + SHIFT + Tab", cycle(true), "Janelas: Janela anterior")
bind("SUPER + ALT + left", hl.dsp.focus({ direction = "left" }), "Janelas: Foco para a esquerda")
bind("SUPER + ALT + right", hl.dsp.focus({ direction = "right" }), "Janelas: Foco para a direita")
bind("SUPER + ALT + up", hl.dsp.focus({ direction = "up" }), "Janelas: Foco para cima")
bind("SUPER + ALT + down", hl.dsp.focus({ direction = "down" }), "Janelas: Foco para baixo")
bind("SUPER + SHIFT + left", hl.dsp.window.move({ monitor = "l" }), "Janelas: Mandar para o monitor da esquerda")
bind("SUPER + SHIFT + right", hl.dsp.window.move({ monitor = "r" }), "Janelas: Mandar para o monitor da direita")
bind("SUPER + mouse:272", hl.dsp.window.drag(), "Janelas: Mover com o mouse", { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), "Janelas: Redimensionar com o mouse", { mouse = true })

-- ── Áreas de trabalho (modules/areas.lua: every screen at once, or each
-- screen on its own, as chosen in Configurações → Monitores) ───────────────
for i = 1, 9 do
  bind("SUPER + " .. i, function() areas.go(i) end, "Áreas: Ir para a área (1 a 9)")
  bind("SUPER + SHIFT + " .. i, function() areas.move(i) end, "Áreas: Mandar a janela para a área (1 a 9)")
end
bind("CTRL + SUPER + left", function() areas.step(-1) end, "Áreas: Área anterior")
bind("CTRL + SUPER + right", function() areas.step(1) end, "Áreas: Próxima área")
bind("CTRL + SUPER + D", function() areas.empty() end, "Áreas: Nova área vazia")
bind("SUPER + mouse_down", function() areas.step(1) end, "Áreas: Próxima área")
bind("SUPER + mouse_up", function() areas.step(-1) end, "Áreas: Área anterior")

-- ── Mídia (also work on the lock screen) ────────────────────────────────────
run("XF86AudioRaiseVolume", "volume_up", "Mídia: Aumentar o volume", { locked = true, repeating = true })
run("XF86AudioLowerVolume", "volume_down", "Mídia: Diminuir o volume", { locked = true, repeating = true })
run("XF86AudioMute", "volume_mute", "Mídia: Mudo", { locked = true })
run("XF86AudioMicMute", "mic_mute", "Mídia: Microfone mudo", { locked = true })
run("XF86MonBrightnessUp", "brightness_up", "Mídia: Aumentar o brilho", { locked = true, repeating = true })
run("XF86MonBrightnessDown", "brightness_down", "Mídia: Diminuir o brilho", { locked = true, repeating = true })
run("XF86AudioPlay", "media_play", "Mídia: Tocar / pausar", { locked = true })
run("XF86AudioPause", "media_play", "Mídia: Tocar / pausar", { locked = true })
run("XF86AudioNext", "media_next", "Mídia: Próxima música", { locked = true })
run("XF86AudioPrev", "media_prev", "Mídia: Música anterior", { locked = true })

-- ── Touchpad gestures (Configurações → Gestos) ──────────────────────────────
-- The shell writes each position's choice as a name (dotfiles_gestures.lua,
-- data only, read by actions.data_file); each name is checked against the
-- tables below, which build the gesture here, so the file never holds a
-- command. A missing position, an unknown name or a bad file: that
-- position's default (the gestures from the Windows setup). Hyprland
-- doesn't list gestures: hypr-atalhos (Super+F1) reads the same file, so
-- keep its positions, names and defaults the same as here.
local gesture_actions = {
  cycle_prev    = cycle(true),
  cycle_next    = cycle(false),
  overview      = launch("overview"),
  launcher      = launch("launcher"),
  controlcenter = launch("controlcenter"),
  empty_area    = function() areas.empty() end,
  media_next    = launch("media_next"),
  media_prev    = launch("media_prev"),
  media_play    = launch("media_play"),
  volume_up     = launch("volume_up"),
  volume_down   = launch("volume_down"),
  capture       = launch("capture"),
  lock          = launch("lock"),
  none          = false,
}
-- position, fingers, direction, default. Windows uses a 4-finger tap;
-- libinput has no such tap, so a 4-finger pinch
local gesture_places = {
  { "3:left", 3, "left", "cycle_prev" },
  { "3:right", 3, "right", "cycle_next" },
  { "3:up", 3, "up", "overview" },
  { "3:down", 3, "down", "empty_area" },
  { "4:up", 4, "up", "media_next" },
  { "4:down", 4, "down", "media_prev" },
  { "4:pinch", 4, "pinch", "media_play" },
}
local chosen_gestures = a.data_file("dotfiles_gestures") or {}

-- The chosen name of a position if it is one of `known`, else the default
local function gesture_choice(position, known, default)
  local name = rawget(chosen_gestures, position)
  if type(name) == "string" and known[name] ~= nil then
    return name
  end
  return default
end

for _, place in ipairs(gesture_places) do
  local action = gesture_actions[gesture_choice(place[1], gesture_actions, place[4])]
  if action then
    hl.gesture({ fingers = place[2], direction = place[3], action = action })
  end
end

-- 4 fingers sideways: switch areas (areas.gestures: the areas' mode, known
-- only once hyprland.lua has read the settings, so it calls this then), the
-- previous / next window, or nothing
local side_choices = { areas = true, cycle = true, none = true }
local function side_gesture()
  local name = gesture_choice("4:side", side_choices, "areas")
  if name == "areas" then
    areas.gestures()
  elseif name == "cycle" then
    hl.gesture({ fingers = 4, direction = "left", action = cycle(true) })
    hl.gesture({ fingers = 4, direction = "right", action = cycle(false) })
  end
end

return { side_gesture = side_gesture }
