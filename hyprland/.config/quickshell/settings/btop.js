.pragma library

// btop's colors from the shell's theme: ~/.config/btop/themes/dotfiles.theme,
// the color_theme of btop.conf (btop reads it when it opens; a missing one
// leaves its default colors). Plain JS: read by the shell (state/SettingsApply)
// and by the tests.

// btop key -> Theme role. Graphs go green -> yellow -> red, titles in the
// accent's light tone, boxes and lines in a discreet bg2; the background is
// the terminal's (theme_background = false in btop.conf).
var ROLES = [
    ["main_bg", "bgHard"],
    ["main_fg", "fg"],
    ["title", "accentLight"],
    ["hi_fg", "yellow"],
    ["selected_bg", "bg2"],
    ["selected_fg", "fg"],
    ["inactive_fg", "gray"],
    ["graph_text", "fg4"],
    ["meter_bg", "bg1"],
    ["proc_misc", "aqua"],
    ["cpu_box", "bg2"],
    ["mem_box", "bg2"],
    ["net_box", "bg2"],
    ["proc_box", "bg2"],
    ["div_line", "bg2"],
    ["temp_start", "green"],
    ["temp_mid", "yellow"],
    ["temp_end", "red"],
    ["cpu_start", "green"],
    ["cpu_mid", "yellow"],
    ["cpu_end", "red"],
    ["free_start", "aqua"],
    ["free_mid", "aqua"],
    ["free_end", "green"],
    ["cached_start", "blue"],
    ["cached_mid", "blue"],
    ["cached_end", "aqua"],
    ["available_start", "yellow"],
    ["available_mid", "yellow"],
    ["available_end", "orange"],
    ["used_start", "orange"],
    ["used_mid", "red"],
    ["used_end", "red"],
    ["download_start", "blue"],
    ["download_mid", "aqua"],
    ["download_end", "green"],
    ["upload_start", "purple"],
    ["upload_mid", "red"],
    ["upload_end", "orange"],
    ["process_start", "green"],
    ["process_mid", "yellow"],
    ["process_end", "red"]
]

// Only a plain "#rrggbb" (what a QML color with full alpha prints) goes into
// the file; anything else is left out, and btop keeps its own color there
function hex(value) {
    const s = String(value)
    return /^#[0-9a-f]{6}$/.test(s) ? s : ""
}

// theme: the Theme's colors by role (anything String() turns into "#rrggbb")
function themeText(theme) {
    let text = "# Written by the shell from its theme; rewritten at every change.\n"
    for (const [key, role] of ROLES) {
        const v = hex(theme[role])
        if (v !== "")
            text += `theme[${key}]="${v}"\n`
    }
    return text
}
