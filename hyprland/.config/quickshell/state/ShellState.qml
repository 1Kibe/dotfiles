pragma Singleton

import QtQuick
import Quickshell

// Shared state of the shell's popups: one panel open at a time, on one
// monitor. Panels: "power", "network", "volume", "bluetooth", "media",
// "system".
Singleton {
    id: root

    property string openPanel: ""   // "" = all closed
    property string openOn: ""      // monitor name
    property string mediaPlayer: "" // dbusName of the player picked in the music panel
    // Opened by a keybind (IPC) rather than a click: the popup grab needs a
    // recent click on the bar, so those panels use a Hyprland focus grab
    property bool openedByKey: false

    function toggle(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
            openedByKey = false
            openPanel = panel
            openOn = monitor
        }
    }

    function toggleByKey(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
            openedByKey = true
            openPanel = panel
            openOn = monitor
        }
    }

    function close() {
        openPanel = ""
        openOn = ""
    }

    function isOpen(panel, monitor) {
        return monitor !== "" && openPanel === panel && openOn === monitor
    }
}
