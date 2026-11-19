import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The Wi-Fi list, in the control center's Wi-Fi section and in the bar's
// network panel: the Wi-Fi switch, the cable's state, the networks and
// "Mais opções…". Long lists: the connected and the saved networks first,
// then by signal, the first five, "Mostrar mais N redes" for the rest
// (scrolling inside past maxListHeight), and a search from nine networks on;
// networks with no name or a weak signal are left out. Names from outside
// go through lists.js trim() and show as plain text. Known or open
// networks connect on click; new ones ask for the password right under the
// row. The password is never stored or logged here: it goes to
// NetworkManager and the field is cleared. Every opening starts clean (no
// row open, no error, no search, the short list).
ColumnLayout {
    id: root

    // The list showing (its panel or section open)
    required property bool active
    // The most the networks take before scrolling inside
    property real maxListHeight: 360
    // The item the control center's keyboard is on (-1 none); see keyItems
    property int keyIndex: -1
    // The search field gave the keyboard back (Esc, Tab, Enter)
    signal keysReleased()

    readonly property var wifiDevice: WifiScan.wifiDevice
    readonly property var wiredDevice: WifiScan.wiredDevice
    readonly property var all: wifiDevice && Networking.wifiEnabled ? wifiDevice.networks.values : []
    readonly property var list: Lists.networks(all, { query: query, showAll: showAll, minSignal: Theme.wifiMinSignal })

    // Kept here by name rather than inside each row: the Repeater rebuilds
    // its rows whenever the sorted list changes (a signal update). Only one
    // row is expanded at a time.
    property string selected: ""   // network with the password field or actions open
    property string failed: ""     // network of the last failed connection
    property string query: ""
    property bool showAll: false

    function signalIcon(strength) {
        return strength < 25 ? "󰤟" : strength < 50 ? "󰤢" : strength < 75 ? "󰤥" : "󰤨"
    }

    onActiveChanged: {
        selected = ""
        failed = ""
        query = ""
        showAll = false
        search.text = ""
    }

    // ── The control center's keyboard ──
    // Its items, in order: the switch, the search (when it shows), each
    // network shown, "Mostrar mais" (when some are left out), "Mais opções…"
    readonly property var keyItems: Lists.wifiKeys(wifiDevice !== null, list)
    readonly property int keyCount: keyItems.length
    function keyOn(kind, i) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind && (i === undefined || it.index === i)
    }
    // Enter on an item: the same as a click
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "switch")
            Networking.wifiEnabled = !Networking.wifiEnabled
        else if (it.kind === "search")
            search.forceActiveFocus()
        else if (it.kind === "network")
            rows.itemAt(it.index)?.press()
        else if (it.kind === "more")
            showAll = true
        else if (it.kind === "options")
            openOptions()
    }
    function openOptions() {
        ShellState.close()
        // Anything the list does not cover (VPN, static IP, hidden networks)
        Quickshell.execDetached(["nm-connection-editor"])
    }

    Layout.fillWidth: true
    spacing: 2

    // Header: Wi-Fi switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 34

        Text {
            Layout.fillWidth: true
            text: "Wi-Fi"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        PanelSwitch {
            visible: root.wifiDevice !== null
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: Theme.radius
                color: Theme.clear
                visible: root.keyOn("switch")
                border.width: Theme.focusWidth
                border.color: Theme.focusRing
            }
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
        textFormat: Text.PlainText
        text: root.wifiDevice === null ? "Sem Wi-Fi neste computador"
            : !Networking.wifiEnabled ? "Wi-Fi desligado"
            : root.all.length === 0 ? "Procurando redes…"
            : root.list.shown.length === 0 && root.query !== "" ? "Nenhuma rede com esse nome" : ""
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    // The search, from SEARCH_FROM networks on
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        visible: root.list.search
        implicitHeight: 28
        radius: Theme.radius
        color: Theme.bg1
        border.width: root.keyOn("search") || search.activeFocus ? Theme.focusWidth : 0
        border.color: Theme.focusRing

        TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            selectionColor: Theme.accent
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            maximumLength: 32
            clip: true
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.keysReleased()
            Keys.onTabPressed: root.keysReleased()
            Keys.onBacktabPressed: root.keysReleased()
            onAccepted: root.keysReleased()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Buscar rede"
                textFormat: Text.PlainText
                color: Theme.gray
                font: search.font
            }
        }
    }

    // The networks: scrolling inside past maxListHeight
    Flickable {
        id: flick
        Layout.fillWidth: true
        implicitHeight: Math.min(networks.implicitHeight, root.maxListHeight)
        contentWidth: width
        contentHeight: networks.implicitHeight
        interactive: networks.implicitHeight > root.maxListHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: networks
            width: flick.width
            spacing: 2

            Repeater {
                id: rows
                model: root.list.shown

                // One network: its row, the error line, and under it either the
                // actions (connected) or the password field (new secured network)
                ColumnLayout {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property string name: modelData.name
                    readonly property string shownName: Lists.trim(name)
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open
                    readonly property bool expanded: root.selected === name
                    readonly property int strength: Math.round(modelData.signalStrength * 100)
                    property bool showPassword: false

                    // Connected or needing a password: toggle the row open.
                    // Known or open: connect right away with what NetworkManager has.
                    function press() {
                        root.failed = ""
                        if (entry.modelData.connected || (entry.secured && !entry.modelData.known))
                            root.selected = entry.expanded ? "" : entry.name
                        else
                            entry.modelData.connect()
                    }

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
                        text: entry.shownName
                        keyFocus: root.keyOn("network", entry.index)
                        detail: entry.modelData.connected ? "conectada"
                              : entry.modelData.stateChanging ? "conectando…"
                              : entry.secured ? "󰌾" : ""
                        onClicked: entry.press()
                        onKeyFocusChanged: {
                            if (keyFocus) {
                                const y = entry.y
                                if (y < flick.contentY)
                                    flick.contentY = y
                                else if (y + height > flick.contentY + flick.height)
                                    flick.contentY = y + height - flick.height
                            }
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
                        textFormat: Text.PlainText
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
                                    textFormat: Text.PlainText
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
                                root.keysReleased()
                            }
                        }
                    }
                }
            }
        }
    }

    PanelRow {
        visible: root.list.hidden > 0
        icon: ""
        text: `Mostrar mais ${root.list.hidden} ${root.list.hidden === 1 ? "rede" : "redes"}`
        keyFocus: root.keyOn("more")
        onClicked: root.showAll = true
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
        keyFocus: root.keyOn("options")
        onClicked: root.openOptions()
    }
}
