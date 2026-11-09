pragma Singleton

import QtQuick
import Quickshell

// Shared state of the shell's popups: one panel open at a time, on one
// monitor. Panels: "power", "network", "volume", "bluetooth", "media",
// "system".
Singleton {
    id: root

    // Compared through isOpen() by each bar button; Bar.qml also reads them
    // directly for the keybind focus grab. Opening one panel replaces any
    // other, even on another monitor.
    property string openPanel: ""   // "" = all closed
    property string openOn: ""      // monitor name
    // Set by bar/MediaPanel, read by state/MediaState
    property string mediaPlayer: "" // dbusName of the player picked in the music panel
    // Opened by a keybind (IPC) rather than a click: the popup grab needs a
    // recent click on the bar, so those panels use a Hyprland focus grab
    property bool openedByKey: false

    // A click on a bar button (PowerButton, NetworkStatus, CenterIsland...)
    function toggle(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
            openedByKey = false
            openPanel = panel
            openOn = monitor
        }
    }

    // The IPC handlers in shell.qml (keybinds and scripts): same as toggle,
    // but marks the panel for the Hyprland focus grab
    function toggleByKey(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
            openedByKey = true
            openPanel = panel
            openOn = monitor
        }
    }

    // Esc, a click outside, a panel action that is done, or another popup
    // (clipboard, capture) opening
    function close() {
        openPanel = ""
        openOn = ""
    }

    // A bar whose monitor is not known yet (name "") is never open
    function isOpen(panel, monitor) {
        return monitor !== "" && openPanel === panel && openOn === monitor
    }
}
