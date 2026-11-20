.pragma library
.import "../settings/hyprland.js" as Hypr
.import "../control/lists.js" as Lists

// The minimized windows' list, for state/MinimizeState and the strip.
// Plain JS: read by the shell and by the tests. Each entry: { address
// ("0x…"), cls, title, monitor (name), area (0 unknown), floating, at:
// { x, y, w, h }, shot ("" none), attention }. Everything taken from
// Hyprland is checked: the address, whole numbers, texts cut.

var SPECIAL = "special:minimizadas"
var TEXT_MAX = 120
var MAX_AREAS = 20

function cut(text, max) {
    return typeof text === "string" ? text.slice(0, max) : ""
}
function whole(v) {
    return typeof v === "number" && isFinite(v) ? Math.round(v) : 0
}
// The area of a workspace id, the overview's rule: with the areas together
// N*10+k is N (never a multiple of 10); separate, the id is the area
// (1 to MAX_AREAS); 0 for anything else
function areaOf(id, together) {
    if (!Number.isInteger(id))
        return 0
    if (together)
        return id >= 11 && id <= MAX_AREAS * 10 + 9 && id % 10 !== 0 ? Math.floor(id / 10) : 0
    return id >= 1 && id <= MAX_AREAS ? id : 0
}

// An entry from a client of "hyprctl -j clients"; monitors: { id: name };
// null when the address is not valid
function entryOf(c, monitors, together) {
    if (!c || typeof c !== "object")
        return null
    const address = Hypr.windowAddress(String(c.address || ""))
    if (address === "")
        return null
    const at = Array.isArray(c.at) ? c.at : [0, 0]
    const size = Array.isArray(c.size) ? c.size : [0, 0]
    const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
    const mon = monitors && Object.prototype.hasOwnProperty.call(monitors, c.monitor) ? String(monitors[c.monitor]) : ""
    return {
        address: address,
        cls: cut(String(c.class || ""), TEXT_MAX),
        title: cut(String(c.title || ""), TEXT_MAX),
        monitor: cut(mon, 64),
        area: areaOf(whole(ws.id), together === true),
        floating: c.floating === true,
        at: { x: whole(at[0]), y: whole(at[1]), w: Math.max(0, whole(size[0])), h: Math.max(0, whole(size[1])) },
        shot: "",
        attention: false
    }
}

// The list after a restart of the shell: the clients already hidden
function fromClients(list, monitors, together) {
    return Lists.toList(list).filter(c => c && c.workspace && c.workspace.name === SPECIAL)
        .map(c => entryOf(c, monitors, together)).filter(e => e !== null)
}

// A new list each time (the bindings follow)
function push(entries, e) {
    return entries.filter(x => x.address !== e.address).concat([e])
}
function remove(entries, address) {
    return entries.filter(x => x.address !== address)
}
function last(entries) {
    return entries.length > 0 ? entries[entries.length - 1] : null
}
function update(entries, address, fields) {
    return entries.map(x => x.address === address ? Object.assign({}, x, fields) : x)
}

// The entries a screen shows: its own, and on the first screen the ones of
// a screen that is not on now
function forMonitor(entries, name, onNames, first) {
    const on = Lists.toList(onNames)
    return entries.filter(e => e.monitor === name || (name === first && !on.includes(e.monitor)))
}

// The wire's dots: one per window up to 8; with more, 7 and a dash
function dots(n) {
    return n <= 8 ? { count: Math.max(0, n), more: false } : { count: 7, more: true }
}

// The most recent entry of an app (ids: class, desktop id, StartupWMClass;
// compared without case), or null
function matchApp(entries, ids) {
    const want = Lists.toList(ids).filter(i => typeof i === "string" && i !== "").map(i => i.toLowerCase())
    for (let i = entries.length - 1; i >= 0; i--) {
        if (want.includes(entries[i].cls.toLowerCase()))
            return entries[i]
    }
    return null
}
