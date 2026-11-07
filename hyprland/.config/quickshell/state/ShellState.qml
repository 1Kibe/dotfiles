pragma Singleton

import QtQuick
import Quickshell

// Shared state of the shell's popups: one panel open at a time, on one
// monitor. Panels: "power", "network", "volume", "bluetooth", "media".
Singleton {
    id: root

    property string openPanel: ""   // "" = all closed
    property string openOn: ""      // monitor name
    property string mediaPlayer: "" // dbusName of the player picked in the music panel

    function toggle(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
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
