import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.state

// Bluetooth panel: adapter on/off and a card per device: connected,
// paired, and "Por perto" (found by "Procurar", which only scans while
// the panel is open).
DropPanel {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var devices: powered ? adapter.devices.values : []
    // The three lists of cards are disjoint; a nearby device without a name
    // is left out, as it could not be told apart
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => d.paired && !d.connected)
    readonly property var nearby: devices.filter(d => !d.paired && !d.connected && d.name !== "")
    readonly property bool scanning: adapter !== null && adapter.discovering
    // rfkill soft block: enabling the adapter alone does nothing, it has to
    // be unblocked first (see the switch below)
    readonly property bool blocked: adapter !== null && adapter.state === BluetoothAdapterState.Blocked

    panelWidth: 320

    // A scan never outlives the panel: stop it when the panel closes
    onOpenChanged: {
        if (!open && scanning)
            adapter.discovering = false
    }

    // After an rfkill unblock: BlueZ takes a moment to see the adapter as
    // usable, so the power on waits 1 s instead of failing right away
    Timer {
        id: powerOn
        interval: 1000
        onTriggered: {
            if (root.adapter !== null && !root.adapter.enabled)
                root.adapter.enabled = true
        }
    }

    // Grey caption above each list; wraps for the long rfkill message
    component SectionLabel: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        wrapMode: Text.WordWrap
        Layout.topMargin: 6
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // Header: adapter switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 34

        Text {
            Layout.fillWidth: true
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        PanelSwitch {
            checked: root.powered
            onToggled: {
                if (root.blocked) {
                    // /dev/rfkill is writable by the session user (uaccess):
                    // unblock, then power on once BlueZ sees it
                    Quickshell.execDetached(["rfkill", "unblock", "bluetooth"])
                    powerOn.restart()
                } else {
                    root.adapter.enabled = !root.adapter.enabled
                }
            }
        }
    }

    // Off or blocked: the only thing in the panel besides the switch and the
    // "Mais opções…" row
    SectionLabel {
        visible: !root.powered
        Layout.bottomMargin: 6
        text: root.blocked ? "Bloqueado pelo sistema (rfkill) — ligue a chave para desbloquear" : "Bluetooth desligado"
    }

    SectionLabel {
        visible: root.connected.length > 0
        text: "Conectados"
    }
    Repeater {
        model: root.connected
        DeviceCard {
            required property var modelData
            device: modelData
        }
    }

    SectionLabel {
        visible: root.paired.length > 0
        text: "Pareados"
    }
    Repeater {
        model: root.paired
        DeviceCard {
            required property var modelData
            device: modelData
        }
    }

    // Nearby: scan on demand
    RowLayout {
        visible: root.powered
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 6
        Layout.topMargin: 6

        Text {
            Layout.fillWidth: true
            text: "Por perto"
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            visible: root.scanning
            text: "󰑓"
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            RotationAnimation on rotation {
                running: root.scanning
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }
        BarItem {
            text: root.scanning ? "Parar" : "Procurar"
            onClicked: root.adapter.discovering = !root.scanning
        }
    }
    // BlueZ keeps devices found by an earlier scan, so they stay listed after
    // "Parar" until they drop off
    Repeater {
        model: root.scanning || root.nearby.length > 0 ? root.nearby : []
        DeviceCard {
            required property var modelData
            device: modelData
        }
    }
    SectionLabel {
        visible: root.scanning && root.nearby.length === 0
        text: "Procurando aparelhos…"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.bg2
    }

    PanelRow {
        icon: "󰒓"
        text: "Mais opções…"
        // Closes the panel first so the new terminal gets the focus. The
        // window class matches a float rule in hypr/modules/rules.lua.
        onClicked: {
            ShellState.close()
            Quickshell.execDetached(["alacritty", "--class", "bluetui", "-e", "bluetui"])
        }
    }
}
