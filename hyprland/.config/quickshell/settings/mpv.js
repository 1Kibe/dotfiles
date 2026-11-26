.pragma library

// mpv's interface (uosc) in the theme's colors: ~/.config/mpv/cores.conf,
// included at the end of mpv.conf, with one script-opts line that gives
// uosc's color option over the one in script-opts/uosc.conf. Plain JS:
// read by state/SettingsApply and by the tests. Every color is checked as
// "#rrggbb" here: a bad one throws and nothing is written.

// uosc's color names and the role of each (uosc.conf's line, today's values)
var COLORS = [
    ["foreground", "fg"],
    ["foreground_text", "bg"],
    ["background", "bg"],
    ["background_text", "fg"],
    ["window_border", "bgHard"],
    ["curtain", "bgHard"],
    ["success", "green"],
    ["error", "red"],
    ["match", "yellow"],
    ["heatmap", "blue"]
]

function hex(colors, role) {
    const c = colors[role]
    if (!Object.prototype.hasOwnProperty.call(colors, role) || typeof c !== "string" || !/^#[0-9a-f]{6}$/.test(c))
        throw new Error(`mpv: cor inválida (${role})`)
    return c.slice(1)
}

// colors: the Theme's colors by role ("#rrggbb")
function mpvConf(colors) {
    const value = COLORS.map(([name, role]) => `${name}=${hex(colors, role)}`).join(",")
    return "# Written by the shell from its theme (Configurações → Tema): rewritten\n"
        + "# at every change. mpv.conf includes it; uosc takes these colors.\n"
        + `script-opts-append=uosc-color=${value}\n`
}
