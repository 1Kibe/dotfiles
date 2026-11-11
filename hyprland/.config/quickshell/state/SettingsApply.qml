pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "../settings/appearance.js" as Appearance
import "../settings/serialize.js" as Serialize
import "../settings/schema.js" as Schema

// Takes each new choice of SettingsStore where it goes: inside the shell,
// the Theme's motion; out of it, later, the generated Hyprland files
// (~/.config/hypr/settings.lua, monitors.lua), hypridle, xdg-mime,
// localectl, sysfs. Each area comes with its own task; this is
// the frame they hang on: a handler per key, and `failed` with a short
// fixed message in pt-BR, after which the page shows the value as it was.
Singleton {
    id: root

    readonly property string hyprFile: `${Quickshell.env("HOME")}/.config/hypr/settings.lua`
    readonly property string monitorsFile: `${Quickshell.env("HOME")}/.config/hypr/monitors.lua`

    signal failed(string key, string message)

    // key -> function(value): set by the areas as they are added
    property var handlers: ({})

    Connections {
        target: SettingsStore
        function onChanged(key) {
            const handler = root.handlers[key]
            if (handler)
                handler(SettingsStore.get(key))
        }
    }

    // Inside the shell: the motion of the Theme (which imports nothing, so
    // the login screen can use it alone)
    function applyMotion() {
        if (!SettingsStore.ready)
            return
        Theme.speed = SettingsStore.get("animSpeed")
        Theme.reduceMotion = SettingsStore.get("reduceMotion") === true
    }
    Connections {
        target: SettingsStore
        function onReadyChanged() {
            root.applyMotion()
            root.applyAppearance()
        }
        function onValuesChanged() {
            root.applyMotion()
            root.applyAppearance()
        }
        // The cursor of the apps already running (settings.lua covers the
        // ones started later)
        function onChanged(key) {
            if (key === "cursorTheme" || key === "cursorSize")
                root.applyCursor()
        }
    }
    Connections {
        target: SystemLists
        function onFontsChanged() { root.applyAppearance() }
        function onMonoFontsChanged() { root.applyAppearance() }
        function onCursorThemesChanged() { root.applyAppearance() }
    }
    Component.onCompleted: {
        applyMotion()
        applyAppearance()
    }

    // ── Aparência (T4) ──

    // The Theme's own palette, for the accent (settings/appearance.js)
    function palette() {
        return { red: String(Theme.red), green: String(Theme.green), yellow: String(Theme.yellow),
                 blue: String(Theme.blue), purple: String(Theme.purple), aqua: String(Theme.aqua),
                 orange: String(Theme.orange) }
    }

    // The store's choices into the Theme (a font this machine does not have
    // keeps the default), then the Hyprland file
    function applyAppearance() {
        if (!SettingsStore.ready)
            return
        const v = SettingsStore.values
        const pair = Appearance.accentPair(v.accent, palette())
        Theme.accent = pair.accent
        Theme.accentLight = pair.light
        Theme.barOpacity = v.barOpacity
        Theme.radius = v.radius
        Theme.textScale = Appearance.textScale(v.textScale)
        Theme.font = SystemLists.usable("fonts", v.fontUi) ? v.fontUi : SettingsStore.defaults.fontUi
        Theme.monoFont = SystemLists.usable("monoFonts", v.fontMono) ? v.fontMono : SettingsStore.defaults.fontMono
        let text = ""
        try {
            text = Appearance.hyprLua(v, pair, SystemLists.cursorsRead && SystemLists.has("cursorThemes", v.cursorTheme),
                                      Serialize.luaValue)
        } catch (e) {
            failed("accent", "Não deu para aplicar no Hyprland")
            return
        }
        hyprWanted = text
        hyprTimer.restart()
    }

    // ~/.config/hypr/settings.lua (read by hyprland.lua before local.lua):
    // written only when its text changes, a moment after the last change,
    // then Hyprland reads its configuration again. The folder is the repo's
    // (stow); the file is in its .gitignore.
    property string hyprWanted: ""
    property bool hyprLoaded: false
    Timer {
        id: hyprTimer
        interval: 300
        onTriggered: root.writeHypr()
    }
    function writeHypr() {
        if (!hyprLoaded || hyprWanted === "")
            return
        if (hyprView.text() === hyprWanted)
            return
        hyprView.setText(hyprWanted)
    }
    FileView {
        id: hyprView
        path: root.hyprFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.hyprLoaded = true
            root.writeHypr()
        }
        onLoadFailed: {
            root.hyprLoaded = true
            root.writeHypr()
        }
        onSaved: Quickshell.execDetached(["hyprctl", "reload"])
        onSaveFailed: root.failed("accent", "Não deu para salvar a configuração do Hyprland")
    }

    // The cursor now: Hyprland's and the GTK apps'. Only a theme this machine
    // has (SystemLists) and a size of the schema; argument lists only
    function applyCursor() {
        const theme = SettingsStore.get("cursorTheme")
        const size = SettingsStore.get("cursorSize")
        if (!SystemLists.has("cursorThemes", theme) || !Schema.KEYS.cursorSize.options.some(o => o.value === size))
            return
        Quickshell.execDetached(["hyprctl", "setcursor", theme, String(size)])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", String(size)])
    }
}
