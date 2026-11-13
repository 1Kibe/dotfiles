-- Áreas de trabalho (Configurações → Monitores): with "Juntas em todas as
-- telas" one area spans every screen. Area N on the screen in position k
-- is Hyprland's workspace N*10+k, kept on that screen; Super+N turns every
-- screen to area N at once, Super+Shift+N sends the window to area N on
-- its own screen, Ctrl+Super+arrows go to the area before or after, and
-- Ctrl+Super+D to the first area empty on every screen. With "Separadas
-- por tela" they do what Hyprland does on its own (workspace N).
--
-- A screen's position comes from the shell (dotfiles_settings.lua sets the
-- global dotfiles_areas = { together, positions = { [port] = k } }); a
-- screen it does not know yet takes the smallest position from 1 to 9 that
-- no screen has, saved or present, and with all nine saved, the smallest
-- one of a screen that is not on now (the same rule the shell uses when it
-- saves it, state/AreasState). Only whole numbers and the shell's checked
-- port names reach Hyprland.
local M = {}

M.MAX_AREAS = 20

-- The shell's choices, or the defaults (together, nothing saved)
local function choices()
  local s = rawget(_G, "dotfiles_areas")
  if type(s) ~= "table" then
    return true, {}
  end
  return s.together ~= false, type(s.positions) == "table" and s.positions or {}
end

local function whole(k, low, high)
  return type(k) == "number" and k % 1 == 0 and k >= low and k <= high
end

-- port name -> position, for every screen that is on
function M.positions()
  local _, saved = choices()
  local taken, out = {}, {}
  for name, k in pairs(saved) do
    if type(name) == "string" and whole(k, 1, 9) and not taken[k] then
      taken[k] = name
    end
  end
  local screens = hl.get_monitors() or {}
  for _, m in ipairs(screens) do
    local k = saved[m.name]
    if whole(k, 1, 9) and taken[k] == m.name then
      out[m.name] = k
    end
  end
  local on = {}
  for _, m in ipairs(screens) do
    on[m.name] = true
  end
  for _, m in ipairs(screens) do
    if not out[m.name] then
      local free
      for k = 1, 9 do
        if not taken[k] then
          free = k
          break
        end
      end
      -- All nine saved: the place of a screen that is not on now
      if not free then
        for k = 1, 9 do
          if not on[taken[k]] then
            free = k
            break
          end
        end
      end
      if free then
        taken[free] = m.name
        out[m.name] = free
      end
    end
  end
  return out
end

-- The area a workspace belongs to: N*10+k is area N; a plain workspace N
-- (from before the areas, or "Separadas por tela") counts as area N
local function area_of_id(id)
  if whole(id, 11, M.MAX_AREAS * 10 + 9) and id % 10 ~= 0 then
    return math.floor(id / 10)
  end
  if whole(id, 1, M.MAX_AREAS) then
    return id
  end
  return nil
end

-- The area a screen shows now (1 when its workspace is none of those)
local function area_of(m)
  local ws = m and m.active_workspace
  return (ws and area_of_id(ws.id)) or 1
end

function M.current()
  return area_of(hl.get_active_monitor())
end

-- Each area's workspace kept on its screen; then every screen shows the
-- area of the focused one
function M.rules()
  local together = choices()
  if not together then
    return
  end
  local pos = M.positions()
  for name, k in pairs(pos) do
    for n = 1, M.MAX_AREAS do
      hl.workspace_rule({ workspace = tostring(n * 10 + k), monitor = name, default = n == 1 })
    end
  end
end

-- Every screen to area n; the focus stays on the screen it was on (with
-- keep_focus false, as after a reload, nothing is focused at all)
function M.go(n, keep_focus)
  if not whole(n, 1, M.MAX_AREAS) then
    return
  end
  local together = choices()
  if not together then
    hl.dispatch(hl.dsp.focus({ workspace = n }))
    return
  end
  local focused = hl.get_active_monitor()
  local pos = M.positions()
  for _, m in ipairs(hl.get_monitors() or {}) do
    local k = pos[m.name]
    if k then
      m:set_workspace(n * 10 + k)
    end
  end
  local now = hl.get_active_monitor()
  if keep_focus ~= false and focused and now and now.name ~= focused.name then
    hl.dispatch(hl.dsp.focus({ monitor = focused.name }))
  end
end

-- The focused window to area n, on its own screen
function M.move(n)
  if not whole(n, 1, M.MAX_AREAS) then
    return
  end
  local together = choices()
  if not together then
    hl.dispatch(hl.dsp.window.move({ workspace = n }))
    return
  end
  local m = hl.get_active_monitor()
  local k = m and M.positions()[m.name]
  if k then
    hl.dispatch(hl.dsp.window.move({ workspace = n * 10 + k }))
  end
end

-- The area before (-1) or after (+1)
function M.step(d)
  local together = choices()
  if not together then
    hl.dispatch(hl.dsp.focus({ workspace = d < 0 and "e-1" or "e+1" }))
    return
  end
  local n = M.current() + (d < 0 and -1 or 1)
  if n >= 1 and n <= M.MAX_AREAS then
    M.go(n)
  end
end

-- The first area with no window on any screen
function M.empty()
  local together = choices()
  if not together then
    hl.dispatch(hl.dsp.focus({ workspace = "empty" }))
    return
  end
  local busy = {}
  for _, ws in ipairs(hl.get_workspaces() or {}) do
    local id = ws.id
    if whole(id, 11, M.MAX_AREAS * 10 + 9) and (ws.windows or 0) > 0 then
      busy[math.floor(id / 10)] = true
    end
  end
  for n = 1, M.MAX_AREAS do
    if not busy[n] then
      M.go(n)
      return
    end
  end
end

-- 4 fingers sideways: with the areas together, the area before or after on
-- every screen (a plain slide); each screen on its own, Hyprland's own
-- gesture (the workspace follows the fingers)
function M.gestures()
  local together = choices()
  if together then
    hl.gesture({ fingers = 4, direction = "left", action = function() M.step(1) end })
    hl.gesture({ fingers = 4, direction = "right", action = function() M.step(-1) end })
  else
    hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
  end
end

-- Windows on a plain workspace N from 1 to 9 (from before the areas, or
-- from "Separadas por tela") go to area N on their own screen, without the
-- focus. 10 and up are left alone: 11 to 19 are area 1 already
function M.adopt()
  local pos = M.positions()
  for _, ws in ipairs(hl.get_workspaces() or {}) do
    local id = ws.id
    local k = ws.monitor and pos[ws.monitor.name]
    if whole(id, 1, 9) and k and (ws.windows or 0) > 0 then
      for _, w in ipairs(ws:get_windows() or {}) do
        local a = type(w.address) == "string" and w.address:lower() or ""
        if not a:find("^0x") then
          a = "0x" .. a
        end
        if a:match("^0x[0-9a-f]+$") and #a <= 18 then
          hl.dispatch(hl.dsp.window.move({ window = "address:" .. a, workspace = id * 10 + k, follow = false }))
        end
      end
    end
  end
end

-- After every load and when a screen comes: the rules, windows from plain
-- workspaces into their areas, and every screen on the area the focused
-- one shows
local function settle()
  M.rules()
  local together = choices()
  if together then
    local n = M.current()
    M.adopt()
    -- No focus here: a reload may come with the session locked
    M.go(n, false)
  end
end
hl.on("config.reloaded", settle)
hl.on("monitor.added", settle)

-- For the bar (hyprctl eval "dotfiles_area.go(3)")
dotfiles_area = M
return M
