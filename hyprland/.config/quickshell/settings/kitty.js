.pragma library

// Kitty's colors from the shell's theme: ~/.config/kitty/cores.conf, which
// kitty.conf includes after its own (fallback) palette. Plain JS: read by the
// shell (state/SettingsApply) and by the tests.

// Kitty key -> Theme role (color0-7: the theme's dark tones; kitty.conf
// keeps today's as the fallback)
var ROLES = [
    ["color0", "ansi0"],
    ["color1", "ansi1"],
    ["color2", "ansi2"],
    ["color3", "ansi3"],
    ["color4", "ansi4"],
    ["color5", "ansi5"],
    ["color6", "ansi6"],
    ["color7", "ansi7"],
    ["background", "bgHard"],
    ["foreground", "fg"],
    ["cursor", "fg"],
    ["cursor_text_color", "bgHard"],
    ["selection_background", "bg2"],
    ["color8", "gray"],
    ["color9", "red"],
    ["color10", "green"],
    ["color11", "yellow"],
    ["color12", "blue"],
    ["color13", "purple"],
    ["color14", "aqua"],
    ["color15", "fg"],
    // The prompt (starship.toml): 208 its orange, 250 the arrow in the
    // accent's light tone (Configurações → Destaque); the 16 colors have none
    ["color208", "orange"],
    ["color250", "accentLight"]
]

// Only a plain "#rrggbb" (what a QML color with full alpha prints) goes into
// the file: any other value of a role throws, and nothing is written
function isHex(value) {
    return /^#[0-9a-f]{6}$/.test(String(value))
}
function hex(value) {
    if (!isHex(value))
        throw new Error("kitty: cor inválida")
    return String(value)
}

// theme: the Theme's colors by role (anything String() turns into "#rrggbb")
function colorsConf(theme) {
    let text = "# Written by the shell from its theme; rewritten at every change.\n"
    for (const [key, role] of ROLES)
        text += `${key} ${hex(theme[role])}\n`
    // The selected text keeps its own color
    text += "selection_foreground none\n"
    return text
}
