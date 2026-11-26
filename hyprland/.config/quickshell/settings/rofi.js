.pragma library

// rofi in the theme's colors: ~/.config/rofi/cores.rasi, imported by
// config.rasi after the system's Gruvbox theme, so it only gives that
// theme's color variables new values (and the icon theme). Plain JS: read
// by state/SettingsApply and by the tests. Every color is checked as
// "#rrggbb" here: a bad one throws and nothing is written.

// The system theme's variables and the role of each
var VARIABLES = [
    ["gruvbox-dark-bg0", "bg"],
    ["gruvbox-dark-bg0-soft", "bg1"],
    ["gruvbox-dark-bg3", "bg2"],
    ["gruvbox-dark-fg0", "text"],
    ["gruvbox-dark-fg1", "fg"],
    ["gruvbox-dark-gray", "gray"],
    ["gruvbox-dark-red-dark", "ansi1"],
    ["gruvbox-dark-red-light", "red"],
    ["gruvbox-dark-yellow-dark", "ansi3"],
    ["gruvbox-dark-yellow-light", "yellow"]
]
// The icon theme of a flavor: a fixed pair by the strict boolean
var ICONS_DARK = "breeze-dark"
var ICONS_LIGHT = "breeze"

function hex(colors, role) {
    const c = colors[role]
    if (!Object.prototype.hasOwnProperty.call(colors, role) || typeof c !== "string" || !/^#[0-9a-f]{6}$/.test(c))
        throw new Error(`rofi: cor inválida (${role})`)
    return c
}

// colors: the Theme's colors by role ("#rrggbb"); escuro: the flavor's
function rofiRasi(colors, escuro) {
    const lines = [
        "/* Written by the shell from its theme (Configurações → Tema): rewritten",
        "   at every change. config.rasi imports it after the system theme. */",
        "configuration {",
        `  icon-theme: "${escuro === true ? ICONS_DARK : ICONS_LIGHT}";`,
        "}",
        "* {"
    ]
    for (const [name, role] of VARIABLES)
        lines.push(`  ${name}: ${hex(colors, role)};`)
    lines.push("}")
    return lines.join("\n") + "\n"
}
