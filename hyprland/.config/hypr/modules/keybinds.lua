-- Keybinds and touchpad gestures. Every bind has a description
-- "<Group>: <text>" (groups: Sistema, Janelas, Áreas, Mídia): it is what
-- hypr-atalhos (Super+F1) and hyprland/README.md show. Commands live in
-- actions.lua; here only keys -> actions.
local a = require("modules.actions")

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

-- Gesture helper: a function that runs an action from actions.lua
local function launch(action)
  return function()
    hl.dispatch(hl.dsp.exec_cmd(a[action]))
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
run("SUPER + X", "powermenu", "Sistema: Menu de energia")
run("SUPER + S", "settings", "Sistema: Configurações")
run("CTRL + ALT + Delete", "powermenu", "Sistema: Menu de energia")
run("SUPER + Tab", "overview", "Sistema: Visão geral das janelas")
run("SUPER + F1", "cheatsheet", "Sistema: Lista de atalhos")
run("CTRL + SHIFT + Escape", "taskmanager", "Sistema: Monitor do sistema (processos)")
run("Print", "capture", "Sistema: Captura de tela (área, janela ou tela, com anotação)")
run("SHIFT + Print", "print_tela", "Sistema: Print da tela inteira")
run("SUPER + SHIFT + S", "print_area", "Sistema: Print de uma área")
run("ALT + Print", "print_janela", "Sistema: Print da janela ativa")
run("SUPER + SHIFT + T", "capture_ocr", "Sistema: Copiar o texto de uma área (OCR)")
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
bind("SUPER + F", hl.dsp.window.float({ action = "toggle" }), "Janelas: Flutuar / voltar ao mosaico")
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

-- ── Áreas de trabalho ───────────────────────────────────────────────────────
for i = 1, 9 do
  bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }), "Áreas: Ir para a área (1 a 9)")
  bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Áreas: Mandar a janela para a área (1 a 9)")
end
bind("CTRL + SUPER + left", hl.dsp.focus({ workspace = "e-1" }), "Áreas: Área anterior")
bind("CTRL + SUPER + right", hl.dsp.focus({ workspace = "e+1" }), "Áreas: Próxima área")
bind("CTRL + SUPER + D", hl.dsp.focus({ workspace = "empty" }), "Áreas: Nova área vazia")
bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Áreas: Próxima área")
bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Áreas: Área anterior")

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

-- ── Touchpad gestures (copied from the Windows setup) ───────────────────────
-- Hyprland doesn't list gestures: keep hypr-atalhos' GESTURES block in sync.
hl.gesture({ fingers = 3, direction = "left", action = cycle(true) })
hl.gesture({ fingers = 3, direction = "right", action = cycle(false) })
hl.gesture({ fingers = 3, direction = "up", action = launch("overview") })
hl.gesture({ fingers = 3, direction = "down", action = function()
  hl.dispatch(hl.dsp.focus({ workspace = "empty" }))
end })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = launch("media_next") })
hl.gesture({ fingers = 4, direction = "down", action = launch("media_prev") })
-- Windows uses a 4-finger tap; libinput has no such tap, so a 4-finger pinch
hl.gesture({ fingers = 4, direction = "pinch", action = launch("media_play") })
