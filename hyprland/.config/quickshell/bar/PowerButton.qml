import QtQuick
import Quickshell
import qs.theme

// Power menu button at the end of the status island. Opens the same menu as
// Super+X (hypr-energia in rofi until the Quickshell power menu exists).
BarItem {
    text: "󰐥"
    tooltip: "Energia"
    onClicked: Quickshell.execDetached(["hypr-energia"])
}
