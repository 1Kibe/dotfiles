import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Io
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
    // its rows whenever the sorted list changes (a signal update). The
    // password field, the open network's warning and the last message are
    // WifiJoin's (one attempt for the whole shell).
    property string selected: ""   // the connected network with its details open
    property string query: ""
    property bool showAll: false
    property bool otherOpen: false // the hidden network form
    property string address: ""    // the connected network's IPv4, only while its details show

    function signalIcon(strength) {
        return strength < 25 ? "󰤟" : strength < 50 ? "󰤢" : strength < 75 ? "󰤥" : "󰤨"
    }

    onActiveChanged: {
        selected = ""
        query = ""
        showAll = false
        otherOpen = false
        address = ""
        search.text = ""
        otherName.text = ""
        otherForm.message = ""
        WifiJoin.reset()
    }

    // The connected network's address: only while its details show, one
    // read at a time, 3 s at most, the output read by a fixed pattern
    readonly property bool detailsShown: active && selected !== "" && list.shown.some(n => n.name === selected && n.connected)
    // A read still running when the details close and open again is read
    // once more as soon as it ends
    property bool addressAgain: false
    property string addressFound: ""
    property int addressLines: 0
    onDetailsShownChanged: {
        address = ""
        addressFound = ""
        if (detailsShown) {
            readAddress()
        } else {
            addressAgain = false
            addressJob.running = false
        }
    }
    function readAddress() {
        const iface = wifiDevice ? wifiDevice.name : ""
        if (!/^[A-Za-z0-9_.-]{1,15}$/.test(iface))
            return
        if (addressJob.running) {
            addressAgain = true
            return
        }
        addressFound = ""
        addressLines = 0
        addressJob.command = ["sh", "-c", 'exec "$@"', "sh", "ip", "-4", "-o", "addr", "show", "dev", iface]
        addressTimeout.restart()
        addressJob.running = true
    }
    Process {
        id: addressJob
        // Line by line, at most 16 lines looked at, only the first address
        // kept; nothing else of the output is kept
        stdout: SplitParser {
            onRead: line => {
                if (++root.addressLines > 16 || root.addressFound !== "")
                    return
                const m = /inet (([0-9]{1,3}\.){3}[0-9]{1,3})\/[0-9]{1,2}/.exec(line)
                if (m)
                    root.addressFound = m[1]
            }
        }
        onExited: code => {
            addressTimeout.stop()
            root.address = code === 0 && root.detailsShown ? root.addressFound : ""
            root.addressFound = ""
            if (root.addressAgain && root.detailsShown) {
                root.addressAgain = false
                root.readAddress()
            }
        }
    }
    Timer {
        id: addressTimeout
        interval: 3000
        onTriggered: addressJob.running = false
    }

    // ── The control center's keyboard ──
    // Its items, in order: the switch, the search (when it shows), each
    // network shown, "Mostrar mais" (when some are left out), "Mais opções…"
    readonly property var keyItems: Lists.wifiKeys(wifiDevice !== null, list, Networking.wifiEnabled)
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
        else if (it.kind === "other")
            toggleOther()
        else if (it.kind === "options")
            openOptions()
    }
    function toggleOther() {
        otherOpen = !otherOpen
        otherName.text = ""
        otherForm.message = ""
        WifiJoin.hiddenError = ""
        if (otherOpen)
            otherName.forceActiveFocus()
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

                // One network: its row, then under it its details (connected),
                // its password field (WifiJoin asking), or the open network's
                // warning (WifiJoin confirming), and the last message
                ColumnLayout {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property string name: modelData.name
                    readonly property string shownName: Lists.trim(name)
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open
                    readonly property int strength: Math.round(modelData.signalStrength * 100)
                    readonly property bool joining: WifiJoin.busy && WifiJoin.target === modelData
                    readonly property bool asking: root.active && WifiJoin.askingNet === modelData
                    readonly property bool confirming: root.active && WifiJoin.confirmingNet === modelData
                    readonly property bool details: root.selected === name && modelData.connected
                    readonly property bool hasError: root.active && WifiJoin.errorNet === modelData && WifiJoin.error !== ""

                    // Connected: the details open and close. Else WifiJoin
                    // decides (saved: connect; open: the warning; new: the field)
                    function press() {
                        if (entry.modelData.connected)
                            root.selected = entry.details ? "" : entry.name
                        else
                            WifiJoin.choose(entry.modelData)
                    }

                    Layout.fillWidth: true
                    spacing: 2

                    onAskingChanged: {
                        if (asking)
                            Qt.callLater(() => password.focusField())
                    }

                    PanelRow {
                        id: row
                        icon: root.signalIcon(entry.strength)
                        text: entry.shownName
                        keyFocus: root.keyOn("network", entry.index)
                        detail: entry.modelData.connected ? "conectada"
                              : entry.joining || entry.modelData.stateChanging ? "conectando…"
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
                            visible: entry.modelData.known && !entry.modelData.connected && row.hovered && !WifiJoin.busy
                            text: "Esquecer"
                            textColor: Theme.gray
                            onClicked: entry.modelData.forget()
                        }
                    }

                    // The last message about this network (fixed words only)
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        visible: entry.hasError
                        text: WifiJoin.error
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: Theme.red
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }

                    // Connected: signal, address, disconnect or forget
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        visible: entry.details
                        spacing: 2

                        Text {
                            text: `Sinal ${entry.strength}%` + (root.address !== "" ? `   Endereço ${root.address}` : "")
                            textFormat: Text.PlainText
                            color: Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                        }
                        RowLayout {
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
                    }

                    // An open network: never joins by itself, and says why
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 8
                        visible: entry.confirming
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Rede aberta: não entra sozinha nesta rede. Qualquer um pode criar outra com o mesmo nome."
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                        }
                        BarItem {
                            text: "Conectar"
                            onClicked: WifiJoin.confirmOpen(entry.modelData)
                        }
                    }

                    // A new secured network, or a saved one whose password no
                    // longer works
                    WifiPassword {
                        id: password
                        visible: entry.asking
                        wrong: entry.hasError && WifiJoin.error === "Senha incorreta"
                        deliver: psk => WifiJoin.submit(entry.modelData, psk)
                        onReleased: root.keysReleased()
                        onEscaped: {
                            WifiJoin.reset()
                            root.keysReleased()
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

    // A hidden network: its name and password (WifiJoin.joinHidden)
    PanelRow {
        visible: root.wifiDevice !== null && Networking.wifiEnabled
        icon: ""
        text: "Outra rede…"
        keyFocus: root.keyOn("other")
        onClicked: root.toggleOther()
    }
    ColumnLayout {
        id: otherForm
        Layout.fillWidth: true
        visible: root.otherOpen && root.active && Networking.wifiEnabled
        spacing: 4

        property string message: ""

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 4
            implicitHeight: 28
            radius: Theme.radius
            color: Theme.bg1
            border.width: otherName.activeFocus ? Theme.focusWidth : 0
            border.color: Theme.focusRing

            TextInput {
                id: otherName
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
                onAccepted: otherPassword.focusField()
                Keys.onEscapePressed: {
                    root.otherOpen = false
                    root.keysReleased()
                }
                Keys.onTabPressed: otherPassword.focusField()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: otherName.text === ""
                    text: "Nome da rede"
                    textFormat: Text.PlainText
                    color: Theme.gray
                    font: otherName.font
                }
            }
        }
        WifiPassword {
            id: otherPassword
            deliver: psk => {
                const bad = WifiJoin.joinHidden(otherName.text, root.wifiDevice ? root.wifiDevice.name : "", psk)
                otherForm.message = bad
                return bad === ""
            }
            onReleased: root.keysReleased()
            onEscaped: {
                root.otherOpen = false
                root.keysReleased()
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            readonly property string shown: otherForm.message !== "" ? otherForm.message
                                             : WifiJoin.hiddenError !== "" ? WifiJoin.hiddenError
                                             : WifiJoin.busy && WifiJoin.target === null ? "Conectando…" : ""
            visible: shown !== ""
            text: shown
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: shown === "Conectando…" ? Theme.gray : Theme.red
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
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
        keyFocus: root.keyOn("options")
        onClicked: root.openOptions()
    }
}
