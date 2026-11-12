.pragma library

// Kitty's colors from the shell's theme: ~/.config/kitty/cores.conf, which
// kitty.conf includes after its own (fallback) palette. Plain JS: read by the
// shell (state/SettingsApply) and by the tests.

// Kitty key -> Theme role. color0-7 stay in kitty.conf: the Theme has no
// dark tones for them yet.
var ROLES = [
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
    // The prompt's orange (starship.toml uses 208: the 16 colors have none)
    ["color208", "orange"]
]

// Only a plain "#rrggbb" (what a QML color with full alpha prints) goes into
// the file; anything else is left out, and kitty.conf's color stays
function hex(value) {
    const s = String(value)
    return /^#[0-9a-f]{6}$/.test(s) ? s : ""
}

// theme: the Theme's colors by role (anything String() turns into "#rrggbb")
function colorsConf(theme) {
    let text = "# Written by the shell from its theme; rewritten at every change.\n"
    for (const [key, role] of ROLES) {
        const v = hex(theme[role])
        if (v !== "")
            text += `${key} ${v}\n`
    }
    // The selected text keeps its own color
    text += "selection_foreground none\n"
    return text
}
