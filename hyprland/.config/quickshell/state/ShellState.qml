pragma Singleton

import QtQuick
import Quickshell

// Shared state of the shell's popups: one panel open at a time, on one
// monitor. Panels: "power", "network", "volume", "bluetooth", "media",
// "system", and "settings" (settings/SettingsPanel, Super+S).
Singleton {
    id: root

    // Compared through isOpen() by each bar button; Bar.qml also reads them
    // directly for the keybind focus grab. Opening one panel replaces any
    // other, even on another monitor.
    property string openPanel: ""   // "" = all closed
    property string openOn: ""      // monitor name
    // Set by bar/MediaPanel, read by state/MediaState
    property string mediaPlayer: "" // dbusName of the player picked in the music panel
    // A panel that continues one of the bar's ends (bar/AttachedPanel: the
    // power menu on the right) names its monitor here while it shows; that
    // bar squares the corner on that end
    property string attachedLeft: ""
    property string attachedRight: ""
    // The settings page asked for (IPC open(page), shell.qml); "" = the first
    property string settingsPage: ""
    // The monitor whose settings panel shows (opening, open or closing), for
    // bar/SettingsZone
    property string settingsOn: ""
    // The screens that have a bar ("Mostrar a barra em"; set by shell.qml).
    // The panels live in the bar: on a screen without one, a keybind opens
    // them on the first screen that has it
    property var barScreens: []
    function panelScreen(monitor) {
        if (barScreens.length === 0 || barScreens.includes(monitor))
            return monitor
        return barScreens[0]
    }

    // A click on a bar button (PowerButton, NetworkStatus, CenterIsland...)
    function toggle(panel, monitor) {
        if (isOpen(panel, monitor)) {
            close()
        } else {
            openPanel = panel
            openOn = monitor
        }
    }

    // The IPC handlers in shell.qml (keybinds and scripts). The same as a
    // click now: the panels live in the bar's own window (Bar.qml), whose
    // focus grab and keyboard work the same either way. Asked from a screen
    // with no bar, it opens on the bar's screen
    function toggleByKey(panel, monitor) {
        toggle(panel, panelScreen(monitor))
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
