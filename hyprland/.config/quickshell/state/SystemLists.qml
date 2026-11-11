pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/schema.js" as Schema

// What this machine has, for the settings' lists (schema `source`): the font
// families (fc-list), the monospaced ones, and the cursor themes (an icon
// theme folder with a "cursors" folder in it). Read at start and again by
// refresh() (the settings panel opening). Only names that pass the schema's
// own pattern for that key are kept, so a value picked here always passes
// the store's check; everything runs as argument lists.
Singleton {
    id: root

    property var fonts: []
    property var monoFonts: []
    property var cursorThemes: []
    // This machine's screens (for the wallpaper's "Tela")
    readonly property var monitors: Quickshell.screens.map(s => s.name)
    // Each list has been read at least once (until then a stored value is
    // trusted as it is: the store already checked its pattern)
    property bool fontsRead: false
    property bool monoRead: false
    property bool cursorsRead: false

    // `source` → its list
    function list(source) {
        return source === "fonts" ? fonts : source === "monoFonts" ? monoFonts
             : source === "cursorThemes" ? cursorThemes : source === "monitors" ? monitors : []
    }
    function has(source, name) {
        return list(source).includes(name)
    }
    // Whether a stored value may be used: in the list once it is read
    function usable(source, name) {
        if (source === "monitors")
            return true
        const read = source === "fonts" ? fontsRead : source === "monoFonts" ? monoRead : cursorsRead
        return !read || has(source, name)
    }

    function names(text, pattern) {
        const seen = {}
        for (const line of text.split("\n")) {
            const n = line.trim()
            if (n !== "" && pattern.test(n))
                seen[n] = true
        }
        return Object.keys(seen).sort((a, b) => a.localeCompare(b))
    }

    function refresh() {
        fontsJob.running = true
        monoJob.running = true
        cursorsJob.running = true
    }
    Component.onCompleted: refresh()

    // The first family name of each font
    Process {
        id: fontsJob
        command: ["fc-list", "-f", "%{family[0]}\\n", ":"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fonts = root.names(text, Schema.KEYS.fontUi.pattern)
                root.fontsRead = true
            }
        }
    }
    Process {
        id: monoJob
        command: ["fc-list", "-f", "%{family[0]}\\n", ":spacing=mono"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monoFonts = root.names(text, Schema.KEYS.fontMono.pattern)
                root.monoRead = true
            }
        }
    }
    // Icon theme folders of the user and of the system with a "cursors"
    // folder; the theme's name is the folder's name
    Process {
        id: cursorsJob
        command: ["find", "-L", `${Quickshell.env("HOME")}/.local/share/icons`, `${Quickshell.env("HOME")}/.icons`,
                  "/usr/share/icons", "-mindepth", "2", "-maxdepth", "2", "-name", "cursors", "-type", "d",
                  "-printf", "%h\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const themes = text.split("\n").map(p => p.split("/").pop()).join("\n")
                root.cursorThemes = root.names(themes, Schema.KEYS.cursorTheme.pattern)
                root.cursorsRead = true
            }
        }
    }
}
