.pragma library

// swayimg in the theme's colors: ~/.config/swayimg/cores.txt, data only.
// swayimg's init.lua reads it as text, line by line, and takes only a line
// `key = "#rrggbb",` with a key of its own fixed list (never run as code);
// a missing or bad file keeps init.lua's own colors. Plain JS: read by
// state/SettingsApply and by the tests. Every color is checked as
// "#rrggbb" here: a bad one throws and nothing is written.

// init.lua's keys and the role of each
var KEYS = [
    ["window", "bgHard"],
    ["panel", "bg"],
    ["check_a", "bg1"],
    ["check_b", "bg2"],
    ["text", "fg"],
    ["border", "accentLight"],
    ["mark", "yellow"]
]

function hex(colors, role) {
    const c = colors[role]
    if (!Object.prototype.hasOwnProperty.call(colors, role) || typeof c !== "string" || !/^#[0-9a-f]{6}$/.test(c))
        throw new Error(`swayimg: cor inválida (${role})`)
    return c
}

// colors: the Theme's colors by role ("#rrggbb")
function swayimgColors(colors) {
    return "# Written by the shell from its theme (Configurações → Tema): rewritten\n"
        + "# at every change. swayimg's init.lua reads it as data.\n"
        + KEYS.map(([key, role]) => `${key} = "${hex(colors, role)}",`).join("\n") + "\n"
}
