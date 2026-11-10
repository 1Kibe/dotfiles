import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.theme
import qs.state

// Network panel: Wi-Fi on/off, cable state and the Wi-Fi networks by
// signal. Known or open networks connect on click; new ones ask for the
// password right under the row. The password is never stored or logged
// here: it goes to NetworkManager and the field is cleared.
AttachedPanel {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    // From Quickshell.Networking (NetworkManager). Copied with slice() since
    // sort() works in place and the list belongs to the device. The connected
    // network comes first, then by signal (0-1).
    readonly property var networks: {
        if (!wifiDevice)
            return []
        return wifiDevice.networks.values.slice()
            .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
    }

    // Kept here by name rather than inside each row: the Repeater rebuilds
    // its rows whenever the sorted list changes (a signal update). Only one
    // row is expanded at a time.
    property string selected: ""   // network with the password field or actions open
    property string failed: ""     // network of the last failed connection

    function signalIcon(strength) {
        return strength < 25 ? "󰤟" : strength < 50 ? "󰤢" : strength < 75 ? "󰤥" : "󰤨"
    }

    // Every opening starts clean: no row expanded, no old error
    onOpenChanged: {
        selected = ""
        failed = ""
    }

    // Scan only while the panel is open
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.open
        when: root.wifiDevice !== null
    }

    // Header: Wi-Fi switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 34

        Text {
            Layout.fillWidth: true
            text: "Wi-Fi"
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        PanelSwitch {
            visible: root.wifiDevice !== null
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    // Information only: the cable has nothing to configure here
    PanelRow {
        visible: root.wiredDevice !== null && root.wiredDevice.connected
        icon: "󰈀"
        text: "Cabo conectado"
        clickable: false
    }

    // Why the list is empty, if it is; hidden once networks show up
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.bottomMargin: 6
        visible: text !== ""
        text: root.wifiDevice === null ? "Sem Wi-Fi neste computador"
            : !Networking.wifiEnabled ? "Wi-Fi desligado"
            : root.networks.length === 0 ? "Procurando redes…" : ""
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    Repeater {
        model: Networking.wifiEnabled ? root.networks : []

        // One network: its row, the error line, and under it either the
        // actions (connected) or the password field (new secured network)
        ColumnLayout {
            id: entry

            required property var modelData
            readonly property string name: modelData.name
            readonly property bool secured: modelData.security !== WifiSecurityType.Open
            readonly property bool expanded: root.selected === name
            readonly property int strength: Math.round(modelData.signalStrength * 100)
            property bool showPassword: false

            Layout.fillWidth: true
            spacing: 2

            // Opening or closing the row always wipes the field and hides the
            // password again; focus goes to it so typing can start at once
            onExpandedChanged: {
                password.text = ""
                showPassword = false
                if (expanded && password.visible)
                    password.forceActiveFocus()
            }

            Connections {
                target: entry.modelData
                // The reason is not shown. A new secured network reopens its
                // password field to try again.
                function onConnectionFailed(reason) {
                    root.failed = entry.name
                    if (entry.secured && !entry.modelData.known)
                        root.selected = entry.name
                }
            }

            PanelRow {
                id: row
                icon: root.signalIcon(entry.strength)
                text: entry.name
                detail: entry.modelData.connected ? "conectada"
                      : entry.modelData.stateChanging ? "conectando…"
                      : entry.secured ? "󰌾" : ""
                // Connected or needing a password: toggle the row open.
                // Known or open: connect right away with what NetworkManager has.
                onClicked: {
                    root.failed = ""
                    if (entry.modelData.connected || (entry.secured && !entry.modelData.known))
                        root.selected = entry.expanded ? "" : entry.name
                    else
                        entry.modelData.connect()
                }

                // Inside the row (PanelRow's trailing slot), only on hover, so
                // the list stays clean
                BarItem {
                    visible: entry.modelData.known && !entry.modelData.connected && row.hovered
                    text: "Esquecer"
                    textColor: Theme.gray
                    onClicked: entry.modelData.forget()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: root.failed === entry.name
                text: "Não conectou: senha errada ou rede fora de alcance"
                wrapMode: Text.WordWrap
                color: Theme.red
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }

            // Connected: disconnect or forget
            RowLayout {
                Layout.leftMargin: 8
                visible: entry.expanded && entry.modelData.connected
                spacing: 4

                BarItem {
                    text: "Desconectar"
                    onClicked: {
                        root.selected = ""
                        entry.modelData.disconnect()
                    }
                }
                BarItem {
                    text: "Esquecer"
                    textColor: Theme.gray
                    onClicked: {
                        root.selected = ""
                        entry.modelData.forget()
                    }
                }
            }

            // New network with a password
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 4
                visible: entry.expanded && !entry.modelData.connected && entry.secured && !entry.modelData.known
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Theme.radius
                    color: Theme.bg1

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: entry.showPassword ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        selectionColor: Theme.accent
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                        clip: true
                        // Enter does the same as the Conectar button
                        onAccepted: connectButton.clicked(Qt.LeftButton)

                        // Placeholder: TextInput has none of its own
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: "Senha"
                            color: Theme.gray
                            font: password.font
                        }
                    }
                }
                BarItem {
                    text: entry.showPassword ? "󰈉" : "󰈈"
                    tooltip: entry.showPassword ? "Esconder a senha" : "Mostrar a senha"
                    onClicked: entry.showPassword = !entry.showPassword
                }
                BarItem {
                    id: connectButton
                    text: "Conectar"
                    onClicked: {
                        if (password.text === "")
                            return
                        root.failed = ""
                        // Handed to NetworkManager, then the field is wiped
                        // right away so the text does not linger in memory here
                        entry.modelData.connectWithPsk(password.text)
                        password.text = ""
                        root.selected = ""
                    }
                }
            }
        }
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
            // Anything the panel does not cover (VPN, static IP, hidden networks)
            Quickshell.execDetached(["nm-connection-editor"])
        }
    }
}
