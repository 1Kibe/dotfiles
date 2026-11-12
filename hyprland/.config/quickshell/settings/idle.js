.pragma library

// The idle times of Configurações → Energia as hypridle listeners:
// ~/.config/hypr/hypridle.gerado.conf, read by hypr-hypridle (which checks
// it again with its own closed grammar). Only numbers come from the
// settings, each one an integer from a fixed list; every command is fixed
// text written here. Plain JS: read by the shell (state/SettingsApply) and
// by the tests.

// "Nunca" (0) takes the step out
var TIMES = [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 7200, 10800, 14400]
// The warning before the lock: the screen dims this long before it
var WARNINGS = [0, 10, 30, 60]
// The screen turns off at least this long after the lock
var OFF_AFTER_LOCK = 10
// hypridle's shortest timeout (hypr-hypridle refuses less)
var MIN_TIMEOUT = 30

var DIM = "timeout 2 qs ipc call lock dim "
var UNDIM = "timeout 2 qs ipc call lock undim"
var LOCK = "loginctl lock-session"
var OFF = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'"
var ON = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
// On power it suspends always; on battery the script checks the battery
// again (a stale file right after plugging in never suspends on power)
var SUSPEND = { ac: "hypr-energia-ociosa suspender-sempre", bat: "hypr-energia-ociosa suspender" }

function isTime(v) {
    return typeof v === "number" && Number.isInteger(v) && TIMES.includes(v)
}

function block(timeout, onTimeout, onResume) {
    let text = `listener {\n    timeout = ${timeout}\n    on-timeout = ${onTimeout}\n`
    if (onResume)
        text += `    on-resume = ${onResume}\n`
    return text + "}\n"
}

// t: { warn, lock, screenOff, suspend } (seconds, 0 = Nunca); source: "ac"
// or "bat". Returns { ok, text } or { ok: false, error } (a short message
// for the page).
function listeners(t, source) {
    if (!t || !isTime(t.lock) || !isTime(t.screenOff) || !isTime(t.suspend)
            || typeof t.warn !== "number" || !WARNINGS.includes(t.warn)
            || (source !== "ac" && source !== "bat"))
        return { ok: false, error: "Tempos inválidos" }
    let text = `# dotfiles-hypridle lock=${t.lock > 0 ? "on" : "off"}\n`
    if (t.lock > 0) {
        // The dim leads to the lock: it never comes before 30 s, so a short
        // lock gets a shorter warning
        if (t.warn > 0) {
            const dim = Math.max(MIN_TIMEOUT, t.lock - t.warn)
            if (dim < t.lock)
                text += "\n" + block(dim, DIM + (t.lock - dim), UNDIM)
        }
        text += "\n" + block(t.lock, LOCK)
    }
    if (t.screenOff > 0) {
        // With the lock on, the screen turns off only after it: a dark
        // screen woken by a key must show the lock, never the open session
        const off = t.lock > 0 ? Math.max(t.screenOff, t.lock + OFF_AFTER_LOCK) : t.screenOff
        text += "\n" + block(off, OFF, ON)
    }
    if (t.suspend > 0)
        text += "\n" + block(t.suspend, SUSPEND[source])
    return { ok: true, text: text }
}
