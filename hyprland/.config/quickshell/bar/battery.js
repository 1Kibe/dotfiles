.pragma library

// The battery's icon and times, for the bar (bar/BatteryStatus.qml) and the
// top of the control center (control/ControlTop.qml). Plain JS.

// One icon per 10% step; index floor(percent / 10), capped at 9 so 100%
// uses the full one; charging has its own
var ICONS = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
var CHARGING = "󰂄"
// The charge is not known (a battery that reports only its full capacity,
// like a virtual machine's): neither a percent nor any energy, and not
// charging. A real battery near empty still reports some energy.
var UNKNOWN = "󰂑"
function known(percentage, energy, charging) {
    return charging === true || Number(percentage) > 0 || Number(energy) > 0
}

function icon(percent, charging) {
    if (charging)
        return CHARGING
    const p = Math.max(0, Math.min(100, Number(percent) || 0))
    return ICONS[Math.min(9, Math.floor(p / 10))]
}

// Seconds as "2h 5min" or "40min"
function duration(seconds) {
    const minutes = Math.round(seconds / 60)
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    return h > 0 ? `${h}h ${m}min` : `${m}min`
}
