import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

// Top bar of one monitor: one translucent strip glued to the top edge, with
// rounded bottom corners. Left: workspaces. Center: clock (an island with
// the music while a player plays).
// Right: status and the power button.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        left: Theme.gap
        right: Theme.gap
    }
    implicitHeight: Theme.barHeight
    // Hyprland adds gaps_out below it; test-quickshell.sh checks the space
    exclusiveZone: Theme.barHeight
    color: Theme.clear
    WlrLayershell.namespace: "quickshell-bar"

    Rectangle {
        anchors.fill: parent
        color: Theme.barFill
        bottomLeftRadius: Theme.barRadius
        bottomRightRadius: Theme.barRadius
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Workspaces {
            monitor: root.hyprMonitor
        }
    }

    CenterIsland {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        monitor: root.hyprMonitor
    }

    RowLayout {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        VolumeStatus {
            monitor: root.hyprMonitor
        }
        NetworkStatus {
            monitor: root.hyprMonitor
        }
        BluetoothStatus {
            monitor: root.hyprMonitor
        }
        BatteryStatus {}
        Separator {}
        PowerButton {
            monitor: root.hyprMonitor
        }
    }
}
