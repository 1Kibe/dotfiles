.pragma library

// Where a minimized window slides: out past the right edge of its screen
// before it is hidden, and in from there when it comes back. Monitors are
// { id, name, active, x, y, w, h } in Hyprland's layout coordinates (the
// size divided by the scale, the same units as a window's at and size).

// Past the edge by more than the window's shadow
var OFF = 64

function whole(v) {
    const n = Number(v)
    return Number.isFinite(n) ? Math.round(n) : NaN
}
function pair(v) {
    return Array.isArray(v) && v.length === 2 ? [whole(v[0]), whole(v[1])] : null
}
function monitorOf(c, mons) {
    return (mons || []).find(m => m.id === c.monitor) ?? null
}
// Another screen to the right of mon (side by side): the window would
// slide into it, so it does not slide at all
function screenToRight(mon, mons) {
    return (mons || []).some(m => m !== mon && m.x >= mon.x + mon.w - 1
        && m.y < mon.y + mon.h && mon.y < m.y + m.h)
}
// The slide out, or null (hidden at once): a window seen on its screen's
// active workspace, with a place and a size, no fullscreen, no screen to
// the right. { mon, at: [x, y], size: [w, h], off: [x, y] }
function out(c, mons) {
    if (!c || typeof c !== "object")
        return null
    const mon = monitorOf(c, mons)
    const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
    const at = pair(c.at), size = pair(c.size)
    if (!mon || mon.active !== ws.id || !at || !size || at.some(isNaN) || size.some(isNaN)
        || size[0] <= 0 || size[1] <= 0 || (Number(c.fullscreen) || 0) !== 0 || c.pinned === true
        || ![mon.x, mon.y, mon.w, mon.h].every(Number.isFinite) || screenToRight(mon, mons))
        return null
    return { mon: mon, at: at, size: size, off: [mon.x + mon.w + OFF, at[1]] }
}
// The slide in on `mon` for an entry that slid out from screen `from`
// (a monitor, or null when unknown): its old place moved to this screen
// and kept inside it; null when there is no screen to slide in on
function back(entryAt, size, from, mon, mons) {
    if (!mon || ![mon.x, mon.y, mon.w, mon.h].every(Number.isFinite) || screenToRight(mon, mons))
        return null
    const s = pair(size)
    if (!s || s.some(isNaN) || s[0] <= 0 || s[1] <= 0)
        return null
    let x, y
    const a = entryAt && Number.isFinite(entryAt.x) ? [entryAt.x, entryAt.y] : null
    if (a && from && Number.isFinite(from.x) && a[0] < from.x + from.w) {
        x = a[0] - from.x + mon.x
        y = a[1] - from.y + mon.y
    } else {
        // Unknown: the middle of the screen
        x = mon.x + (mon.w - s[0]) / 2
        y = mon.y + (mon.h - s[1]) / 2
    }
    x = Math.round(Math.max(mon.x, Math.min(x, mon.x + mon.w - s[0])))
    y = Math.round(Math.max(mon.y, Math.min(y, mon.y + mon.h - s[1])))
    return { to: [x, y], off: [mon.x + mon.w + OFF, y] }
}
// A window found hidden after a restart already past its screen's right
// edge slid out in an earlier run
function wasSlid(c, mons) {
    const mon = monitorOf(c, mons)
    const at = pair(c && c.at)
    return !!(mon && at && !isNaN(at[0]) && at[0] >= mon.x + mon.w)
}
