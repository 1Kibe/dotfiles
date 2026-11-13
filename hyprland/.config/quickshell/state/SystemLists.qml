pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/schema.js" as Schema
import "../settings/monitors.js" as Monitors
import "../settings/input.js" as Input

// What this machine has, for the settings' lists (schema `source`): the font
// families (fc-list), the monospaced ones, and the cursor themes (an icon
// theme folder with a "cursors" folder in it). Read at start and again by
// refresh() (the settings panel opening). Only names that pass the schema's
// own pattern for that key are kept, so a value picked here always passes
// the store's check; everything runs as argument lists. The screens come
// from Hyprland, the turned-off ones too (hyprctl -j monitors all; the
// Quickshell screens leave them out), read again when the screens change;
// only port names of the right shape (settings/monitors.js). Whether there is
// a touchpad comes from Hyprland's devices: only that answer is kept, never
// a device's name (settings/input.js); read again when the Teclado e mouse
// page opens (Hyprland tells nothing when a device is plugged in). The
// keyboard layouts are the system's own list (localectl), short lowercase
// codes only.
Singleton {
    id: root

    property var fonts: []
    property var monoFonts: []
    property var cursorThemes: []
    // This machine's screens, on and off (the wallpaper's "Tela", the bar's)
    property var monitors: []
    // A touchpad among the pointing devices (Configurações → Touchpad)
    property bool hasTouchpad: false
    // The keyboard layouts the system knows (localectl list-x11-keymap-layouts)
    property var layouts: []
    property bool layoutsRead: false
    // Each list has been read at least once (until then a stored value is
    // trusted as it is: the store already checked its pattern)
    property bool fontsRead: false
    property bool monoRead: false
    property bool cursorsRead: false

    // `source` → its list
    function list(source) {
        return source === "fonts" ? fonts : source === "monoFonts" ? monoFonts
             : source === "cursorThemes" ? cursorThemes : source === "monitors" ? monitors
             : source === "layouts" ? layouts : []
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
        monitorsJob.running = true
        devicesJob.running = true
        layoutsJob.running = true
        fontsJob.running = true
        monoJob.running = true
        cursorsJob.running = true
    }
    Component.onCompleted: refresh()

    Process {
        id: monitorsJob
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(text)
                } catch (e) {
                    list = []
                }
                const names = Array.isArray(list) ? list.map(m => m && m.name).filter(n => Monitors.validName(n)) : []
                root.monitors = names.filter((n, i) => names.indexOf(n) === i).sort()
            }
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { monitorsJob.running = true }
    }

    function refreshDevices() {
        devicesJob.running = true
    }
    Process {
        id: devicesJob
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: root.hasTouchpad = Input.hasTouchpad(text)
        }
    }

    // A command that cannot start (no localectl) still ends the reading:
    // an empty list, and no layout is ever applied
    Process {
        id: layoutsJob
        command: ["localectl", "--no-pager", "list-x11-keymap-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.layouts = root.names(text, Schema.KEYS.kbLayout.pattern)
                root.layoutsRead = true
            }
        }
        onRunningChanged: {
            if (!running && !root.layoutsRead)
                layoutsFallback.restart()
        }
    }
    // The output usually lands right after the end; half a second later,
    // still nothing: there is no list
    Timer {
        id: layoutsFallback
        interval: 500
        onTriggered: root.layoutsRead = true
    }

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
