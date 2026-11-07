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
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => d.paired && !d.connected)
    readonly property var nearby: devices.filter(d => !d.paired && !d.connected && d.name !== "")
    readonly property bool scanning: adapter !== null && adapter.discovering

    panelWidth: 320

    onOpenChanged: {
        if (!open && scanning)
            adapter.discovering = false
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
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
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }
    }

    SectionLabel {
        visible: !root.powered
        Layout.bottomMargin: 6
        text: root.adapter !== null && root.adapter.state === BluetoothAdapterState.Blocked
              ? "Bloqueado pelo sistema (rfkill)" : "Bluetooth desligado"
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
        onClicked: {
            ShellState.close()
            Quickshell.execDetached(["alacritty", "--class", "bluetui", "-e", "bluetui"])
        }
    }
}
