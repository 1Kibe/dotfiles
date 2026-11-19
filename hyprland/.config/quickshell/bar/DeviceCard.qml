import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.theme
import "../control/lists.js" as Lists

// One Bluetooth device as a card: icon by type (accent when connected),
// name (or the address for one with none), a state line and a battery bar.
// It only draws: the attempt to connect or pair and the "Esquecer" with its
// second click live in BluetoothList, which outlives the cards (a device
// that pairs moves to another list, and its card is made again).
Rectangle {
    id: root

    // A BluetoothDevice from Bluetooth.defaultAdapter
    required property var device
    // The list's attempt on this device ("connect", "pair", or "")
    property string attempt: ""
    // A fixed message (red) until the next attempt or a connection
    property string error: ""
    property bool keyFocus: false
    // "Esquecer": shown for a paired device; armed waits for the second
    // click; forgetFocus is the keyboard on it
    property bool canForget: false
    property bool forgetArmed: false
    property bool forgetFocus: false
    signal clicked()
    signal forgetClicked()

    readonly property int battery: device.batteryAvailable === true ? Math.round(device.battery * 100) : -1
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
        if (device.pairing || attempt === "pair")
            return "Pareando…"
        if (device.state === BluetoothDeviceState.Connecting || attempt === "connect")
            return "Conectando…"
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Desconectando…"
        if (device.connected)
            return battery >= 0 ? `Conectado · ${battery}%` : "Conectado"
        if (device.paired)
            return "Pareado · clique para conectar"
        return "Novo · clique para parear"
    }

    Layout.fillWidth: true
    implicitHeight: 52
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.veil : Theme.clear
    border.width: keyFocus ? Theme.focusWidth : 0
    border.color: Theme.focusRing
    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }
    // Pressed: a bit smaller; hover: a bit bigger. The spring gives a small
    // bounce instead of a linear change.
    scale: mouse.pressed ? 0.98 : mouse.containsMouse ? 1.01 : 1
    Behavior on scale {
        SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.005 }
    }

    // The pointer anywhere on the card, the "Esquecer" button included
    HoverHandler {
        id: hover
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
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
                textFormat: Text.PlainText
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
                textFormat: Text.PlainText
                maximumLineCount: 1
                text: Lists.deviceLabel(root.device)
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                maximumLineCount: 1
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

        // Only for a paired device, while the pointer or the keyboard is on
        // the card, or while armed
        BarItem {
            visible: root.canForget && (hover.hovered || root.keyFocus || root.forgetFocus || root.forgetArmed)
            text: root.forgetArmed ? "Clique de novo para esquecer" : "Esquecer"
            textColor: root.forgetArmed ? Theme.red : Theme.gray
            keyFocus: root.forgetFocus
            onClicked: root.forgetClicked()
        }
    }
}
