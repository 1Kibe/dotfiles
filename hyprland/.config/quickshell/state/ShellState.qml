pragma Singleton

import QtQuick
import Quickshell

// Shared state of the shell's popups.
Singleton {
    id: root

    // Name of the monitor whose bar shows the power menu ("" = closed)
    property string powerMenuOn: ""

    function togglePowerMenu(monitorName) {
        powerMenuOn = powerMenuOn === monitorName ? "" : monitorName
    }
}
