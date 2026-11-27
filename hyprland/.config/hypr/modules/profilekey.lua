-- Super+T: a tap goes to the next profile (round the order); held, the
-- profiles' selector opens once the key has been down HOLD_MS, and stays
-- open when it is let go. All inside Hyprland: the press starts a one-shot
-- timer, the release of T (any modifier, either order of letting go) ends it.
-- A T typed without Super only reads one flag here: no process, no IPC; the
-- shell is called only for a real Super+T (one call for a tap, one for a
-- hold). The binds are in keybinds.lua, without `locked`: nothing of this
-- runs on the lock screen.
local a = require("modules.actions")

local M = {}

-- How long Super+T has to be held for the selector (milliseconds): the one
-- place to change it
M.HOLD_MS = 400
-- A release that never came (another TTY, a grab): a timer started with
-- each press drops the state this long after it, so the next press starts
-- clean
M.STALE_MS = 2000

local held, opened = false, false
local holdTimer, staleTimer = nil, nil
-- Each press its own number: a timer of an older press never acts, even if
-- turning it off failed
local press_id = 0

local function stop(t)
  if t then
    t:set_enabled(false)
  end
end

-- Back to rest (the timers off)
function M.reset()
  stop(holdTimer)
  stop(staleTimer)
  holdTimer, staleTimer = nil, nil
  held, opened = false, false
end

-- Super+T down. A press while already down (the key's repeat, or the
-- virtual machine sending the press again) changes nothing
function M.press()
  if held then
    return
  end
  held, opened = true, false
  press_id = press_id + 1
  local mine = press_id
  holdTimer = hl.timer(function()
    if mine ~= press_id then
      return
    end
    holdTimer = nil
    if held and not opened then
      opened = true
      hl.exec_cmd(a.profiles_open)
    end
  end, { timeout = M.HOLD_MS, type = "oneshot" })
  staleTimer = hl.timer(function()
    if mine ~= press_id then
      return
    end
    staleTimer = nil
    M.reset()
  end, { timeout = M.STALE_MS, type = "oneshot" })
end

-- T up (with or without Super, Shift or anything): a tap if the selector
-- did not open; otherwise nothing (it stays open)
function M.release()
  if not held then
    return
  end
  local tap = not opened
  M.reset()
  if tap then
    hl.exec_cmd(a.profile_next)
  end
end

-- (a submap or the focused monitor changing in between: start over)
hl.on("keybinds.submap", M.reset)
hl.on("monitor.focused", M.reset)

return M
