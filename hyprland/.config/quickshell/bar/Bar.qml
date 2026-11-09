import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state

// Top bar of one monitor: one translucent strip glued to the top edge, with
// rounded bottom corners. Left: workspaces. Center: clock (an island with
// the music while a player plays). Left also has the CPU, memory and
// temperature rings.
// Right: status and the power button.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    // Hyprland's view of this screen: its name is the key ShellState uses to
    // open a panel on this bar only, so every button below gets it
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)

    anchors {
        top: true
        left: true
        right: true
    }
    // Same side gaps as the windows, so the strip lines up with them
    margins {
        left: Theme.gap
        right: Theme.gap
    }
    implicitHeight: Theme.barHeight
    // Hyprland adds gaps_out below it; test-quickshell.sh checks the space
    exclusiveZone: Theme.barHeight
    color: Theme.clear
    WlrLayershell.namespace: "quickshell-bar"

    // A panel opened by a keybind has no popup grab, so the bar takes the
    // keyboard while it is open, for Esc (see DropPanel)
    readonly property bool keyPanelHere: ShellState.openedByKey && ShellState.openPanel !== ""
                                         && hyprMonitor !== null && ShellState.openOn === hyprMonitor.name
    WlrLayershell.keyboardFocus: keyPanelHere ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Gets the keys only while keyPanelHere gives the bar keyboard focus
    Item {
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    // The window itself is clear; this strip paints the bar, so the rounded
    // bottom corners show what is behind them
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
        Separator {}
        SystemStatus {
            monitor: root.hyprMonitor
        }
    }

    // Centered on the whole bar, not between the two rows, so the clock stays
    // put while the side rows change width. Top-anchored: the island fills the
    // full bar height.
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

        // Only while recording the screen (Super+Alt+R)
        RecordingPill {}
        // Each status button owns its drop panel; the monitor tells it which
        // bar the panel belongs to
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
