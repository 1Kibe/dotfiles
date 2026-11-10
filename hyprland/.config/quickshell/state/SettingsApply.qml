pragma Singleton

import QtQuick
import Quickshell
import qs.theme

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
        function onReadyChanged() { root.applyMotion() }
        function onValuesChanged() { root.applyMotion() }
    }
    Component.onCompleted: applyMotion()
}
