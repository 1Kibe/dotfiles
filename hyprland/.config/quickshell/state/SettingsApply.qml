pragma Singleton

import QtQuick
import Quickshell

// Takes each new choice of SettingsStore out of the shell: the generated
// Hyprland files (~/.config/hypr/settings.lua, monitors.lua), hypridle,
// xdg-mime, localectl, sysfs. Each area comes with its own task; this is
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
}
