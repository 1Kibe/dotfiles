import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

// Top bar of one monitor: one translucent strip glued to the top edge, with
// rounded bottom corners. Left: workspaces and title. Center: clock.
// Right: music, status and the power button (Tasks 4 and 5).
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
        Separator {
            visible: title.visible
        }
        WindowTitle {
            id: title
        }
    }

    Clock {
        anchors.centerIn: parent
    }

    RowLayout {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        VolumeStatus {}
        NetworkStatus {
            monitor: root.hyprMonitor
        }
        BluetoothStatus {}
        BatteryStatus {}
        Separator {}
        PowerButton {
            monitor: root.hyprMonitor
        }
    }
}
