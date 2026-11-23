.pragma library

// Where a minimized window comes back to when Hyprland does not say (its
// old place, moved to the screen it comes back on), and the windows an
// earlier version left past a screen's right edge (it slid them out
// before hiding them). Monitors are { id, name, active, x, y, w, h } in
// Hyprland's layout coordinates (the size divided by the scale, the same
// units as a window's at and size).

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
// The place on `mon` for an entry that was on screen `from` (a monitor, or
// null when unknown): its old place moved to this screen and kept inside
// it; the middle of the screen when the place is not known; null with no
// screen or no size. { to: [x, y] }
function back(entryAt, size, from, mon, mons) {
    if (!mon || ![mon.x, mon.y, mon.w, mon.h].every(Number.isFinite))
        return null
    const s = pair(size)
    if (!s || s.some(isNaN) || s[0] <= 0 || s[1] <= 0)
        return null
    let x, y
    const a = entryAt && Number.isFinite(entryAt.x) ? [entryAt.x, entryAt.y] : null
    if (a && from && Number.isFinite(from.x) && a[0] < from.x + from.w) {
        x = a[0] - from.x + mon.x
        y = a[1] - from.y + mon.y
    } else if (a && !from && a[0] >= mon.x && a[0] < mon.x + mon.w) {
        // On this same screen (no other known): where it was
        x = a[0]
        y = a[1]
    } else {
        // Unknown: the middle of the screen
        x = mon.x + (mon.w - s[0]) / 2
        y = mon.y + (mon.h - s[1]) / 2
    }
    x = Math.round(Math.max(mon.x, Math.min(x, mon.x + mon.w - s[0])))
    y = Math.round(Math.max(mon.y, Math.min(y, mon.y + mon.h - s[1])))
    return { to: [x, y] }
}
// A window found hidden after a restart already past its screen's right
// edge: an earlier version slid it out
function wasSlid(c, mons) {
    const mon = monitorOf(c, mons)
    const at = pair(c && c.at)
    return !!(mon && at && !isNaN(at[0]) && at[0] >= mon.x + mon.w)
}
