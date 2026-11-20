.pragma library
.import "../settings/hyprland.js" as Hypr

// Lua for Hyprland.dispatch, from the minimize module. Only checked values
// get in: a window address (hex) and whole workspace numbers. A class, a
// title or a monitor name never does. Each returns the text, or null.

var SPECIAL = "special:minimizadas"
var MAX_AREAS = 20

function isAddress(text) {
    return typeof text === "string" && /^0x[0-9a-f]{1,16}$/.test(text) && Hypr.windowAddress(text) === text
}
// A workspace to bring a window back to: 1 to MAX_AREAS, or N*10+k
function isWorkspace(n) {
    return typeof n === "number" && Number.isInteger(n) && n >= 1 && n <= MAX_AREAS * 10 + 9
        && (n <= MAX_AREAS || n % 10 !== 0)
}

// To the hidden workspace, without showing it
function hide(address) {
    return isAddress(address)
        ? 'hl.dsp.window.move({ window = "address:' + address + '", workspace = "' + SPECIAL + '", follow = false })'
        : null
}
// Back to a workspace (the screen's active one)
function bringTo(address, workspace) {
    return isAddress(address) && isWorkspace(workspace)
        ? 'hl.dsp.window.move({ window = "address:' + address + '", workspace = ' + workspace + ', follow = false })'
        : null
}
function focus(address) {
    return isAddress(address) ? 'hl.dsp.focus({ window = "address:' + address + '" })' : null
}
function close(address) {
    return isAddress(address) ? 'hl.dsp.window.close({ window = "address:' + address + '" })' : null
}
// The hidden workspace shown by Hyprland (a window there asked for the
// focus): hidden again. The exact Lua is still to be checked on screen
function hideSpecial() {
    return 'hl.dsp.workspace.toggle_special({ name = "minimizadas" })'
}
// Out of fullscreen or maximized (mode "fullscreen" or "maximized")
function unsetFullscreen(address, mode) {
    return isAddress(address) && (mode === "fullscreen" || mode === "maximized")
        ? 'hl.dsp.window.fullscreen({ window = "address:' + address + '", action = "unset", mode = "' + mode + '" })'
        : null
}
