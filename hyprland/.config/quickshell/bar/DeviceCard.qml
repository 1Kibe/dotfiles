import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.theme

// One Bluetooth device as a card: icon by type (accent when connected),
// name, a state line and a battery bar. Click: disconnect, connect, or
// pair and connect. BlueZ sends no failure signal, so a failed attempt is
// detected when the device falls back to disconnected, or after 20 s.
Rectangle {
    id: root

    // A BluetoothDevice from Bluetooth.defaultAdapter, passed in by
    // BluetoothPanel's Repeaters
    required property var device
    property string attempt: ""   // "connect" or "pair" while trying
    // A connect attempt fails only after BlueZ went through Connecting:
    // right after connect() the state can still read Disconnected
    property bool sawConnecting: false
    // Shown in the state line (red) until the next attempt or a connection
    property string error: ""

    readonly property int battery: device.batteryAvailable ? Math.round(device.battery * 100) : -1
    // From the freedesktop icon name BlueZ gives the device (its class);
    // a plain Bluetooth icon for anything unknown
    readonly property string typeIcon: {
        const i = device.icon || ""
        if (i.startsWith("audio-head"))
            return "󰋋"
        if (i.startsWith("audio"))
            return "󰓃"
        if (i === "input-mouse")
            return "󰍽"
        if (i === "input-keyboard")
            return "󰌌"
        if (i === "input-gaming")
            return "󰊴"
        if (i.startsWith("phone"))
            return "󰏲"
        if (i.startsWith("video") || i.includes("tv"))
            return "󰔂"
        if (i === "computer")
            return "󰌢"
        return "󰂯"
    }
    // First match wins: an error, then the transient states, then what a
    // click would do
    readonly property string status: {
        if (error !== "")
            return error
        if (device.pairing)
            return "Pareando…"
        if (device.state === BluetoothDeviceState.Connecting)
            return "Conectando…"
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Desconectando…"
        if (device.connected)
            return battery >= 0 ? `Conectado · ${battery}%` : "Conectado"
        if (device.paired)
            return "Pareado · clique para conectar"
        return "Novo · clique para parear"
    }

    function fail(message) {
        attempt = ""
        sawConnecting = false
        error = message
        timeout.stop()
    }

    function start(kind) {
        error = ""
        attempt = kind
        sawConnecting = false
        timeout.restart()
        if (kind === "pair")
            device.pair()
        else
            device.connect()
    }

    // Only connect and pair are tracked as attempts; a disconnect just shows
    // up in the state line as "Desconectando…"
    function activate() {
        if (device.connected)
            device.disconnect()
        else if (device.paired)
            start("connect")
        else
            start("pair")
    }

    Layout.fillWidth: true
    implicitHeight: 52
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.veil : Theme.clear
    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }
    // Pressed: a bit smaller; hover: a bit bigger. The spring gives a small
    // bounce instead of a linear change.
    scale: mouse.pressed ? 0.98 : mouse.containsMouse ? 1.01 : 1
    Behavior on scale {
        SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.005 }
    }

    // Last resort when BlueZ never reports a state change: the attempt is
    // called failed after 20 s
    Timer {
        id: timeout
        interval: 20000
        onTriggered: root.fail(root.attempt === "pair" ? "Não pareou" : "Não conectou")
    }

    // Follows the attempt through the device's property changes, since no
    // failure signal comes (see the header)
    Connections {
        target: root.device
        // Connected by any path (this click, auto reconnect): attempt over
        function onConnectedChanged() {
            if (root.device.connected) {
                root.attempt = ""
                root.error = ""
                timeout.stop()
            }
        }
        function onStateChanged() {
            if (root.attempt !== "connect")
                return
            if (root.device.state === BluetoothDeviceState.Connecting)
                root.sawConnecting = true
            else if (root.device.state === BluetoothDeviceState.Disconnected && root.sawConnecting)
                root.fail("Não conectou")
        }
        // Pairing ended: paired means go on to connect, otherwise it failed
        function onPairingChanged() {
            if (root.attempt !== "pair" || root.device.pairing)
                return
            if (root.device.paired) {
                root.device.trusted = true   // reconnect by itself next time
                root.start("connect")
            } else {
                root.fail("Não pareou")
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 12

        // Icon circle: accent while connected
        Rectangle {
            implicitWidth: Theme.cardIcon
            implicitHeight: Theme.cardIcon
            radius: width / 2
            color: root.device.connected ? Theme.accent : Theme.bg1
            Behavior on color {
                ColorAnimation { duration: Theme.animNormal }
            }

            Text {
                anchors.centerIn: parent
                text: root.typeIcon
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                // Some devices only announce their address
                text: root.device.name || root.device.address
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                Layout.fillWidth: true
                text: root.status
                elide: Text.ElideRight
                color: root.error !== "" ? Theme.red : Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            // Battery bar, only for devices that report one (-1 otherwise):
            // red up to 15%, yellow up to 30%
            Rectangle {
                visible: root.battery >= 0
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 2
                color: Theme.bg2

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.battery)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.battery <= 15 ? Theme.red : root.battery <= 30 ? Theme.yellow : Theme.green
                }
            }
        }
    }
}
