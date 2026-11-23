.pragma library
.import "../settings/hyprland.js" as Hypr

// Lua for Hyprland.dispatch (and for hyprctl eval, with the areas
// together on every screen), from the overview. Only checked values get
// in: a window address (hex, as Hyprland writes it) and a whole area or
// workspace number. Titles, classes or app names never do. Each function
// returns the text, or null when a value does not pass (nothing is sent).

var ADDRESS = /^0x[0-9a-f]{1,16}$/
var MAX_AREAS = 20          // modules/areas.lua M.MAX_AREAS

function isAddress(text) {
    return typeof text === "string" && ADDRESS.test(text) && Hypr.windowAddress(text) === text
}
// An area of the bar's list (1 to MAX_AREAS)
function isArea(n) {
    return typeof n === "number" && Number.isInteger(n) && n >= 1 && n <= MAX_AREAS
}
// The area of a workspace id: together, N*10+k is area N; separate, the
// id is the area; 0 when it is not an area (special, out of range)
function areaOfWorkspace(id, together) {
    if (typeof id !== "number" || !Number.isInteger(id))
        return 0
    if (together)
        return id >= 11 && id <= MAX_AREAS * 10 + 9 && id % 10 !== 0 ? Math.floor(id / 10) : 0
    return isArea(id) ? id : 0
}
// A workspace id: an area's own (separate screens, 1 to MAX_AREAS) or N*10+k
// (together, k 1 to 9: never a multiple of 10, which modules/areas.lua does
// not take as an area and would make a stray workspace)
function isWorkspace(n) {
    return typeof n === "number" && Number.isInteger(n) && n >= 1 && n <= MAX_AREAS * 10 + 9
        && (n <= MAX_AREAS || n % 10 !== 0)
}

function focusWindow(address) {
    return isAddress(address) ? 'hl.dsp.focus({ window = "address:' + address + '" })' : null
}
function closeWindow(address) {
    return isAddress(address) ? 'hl.dsp.window.close({ window = "address:' + address + '" })' : null
}
// The window to a workspace, without following it
function moveToWorkspace(address, workspace) {
    return isAddress(address) && isWorkspace(workspace)
        ? 'hl.dsp.window.move({ window = "address:' + address + '", workspace = ' + workspace + ', follow = false })'
        : null
}
// Going to an area: on one screen (dispatch) or, with the areas together,
// on every screen at once (hyprctl eval, modules/areas.lua)
function goToArea(area) {
    return isArea(area) ? "hl.dsp.focus({ workspace = " + area + " })" : null
}
function goToAreaTogether(area) {
    return isArea(area) ? "dotfiles_area.go(" + area + ")" : null
}
// Going to a window of another area with the areas together: the area on
// every screen, then the window's focus, in one eval (in this order)
function goToAreaAndFocus(area, address) {
    return isArea(area) && isAddress(address)
        ? "dotfiles_area.go(" + area + ') hl.dispatch(hl.dsp.focus({ window = "address:' + address + '" }))'
        : null
}
