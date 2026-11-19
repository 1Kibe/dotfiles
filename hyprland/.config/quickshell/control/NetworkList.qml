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
// network panel: the header with the state and the Wi-Fi switch, the
// cable's state, the networks in a block with "Outra rede…", and "Mais
// opções…" (the sections' common parts: ListHeader, ListBlock, ListRow).
// Long lists: the connected and the saved networks first,
// then by signal, the first five, "Mostrar mais N redes" for the rest
// (scrolling inside past maxListHeight), and a search from nine networks on;
// networks with no name or a weak signal are left out. Names from outside
// go through lists.js trim() and show as plain text. Known or open
// networks connect on click; new ones ask for the password right under the
// row. The password is never stored or logged here: it goes to
// NetworkManager and the field is cleared. "Esquecer" (a saved network)
// asks for a second click: the first arms it, a second within 300 ms (a
// double click) does nothing, a later one forgets that network's object;
// 5 s, another network, a click elsewhere, the keyboard moving, or the list
// closing (also by the lock) disarm it. Every opening starts clean (no row
// open, no error, no search, the short list).
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

    // The state in the header and on the grid's button: generic words, never
    // a network's name
    readonly property string stateText: {
        const nets = wifiDevice ? wifiDevice.networks.values : []
        return Lists.summary({
            hasWifi: wifiDevice !== null,
            wifiOn: Networking.wifiEnabled,
            wired: wiredDevice !== null && wiredDevice.connected,
            connected: nets.some(n => n.connected),
            connecting: WifiJoin.busy || nets.some(n => n.stateChanging)
        })
    }

    function signalIcon(strength) {
        // nf-md-wifi_strength_1 … 4
        return String.fromCodePoint(strength < 25 ? 0xF091F : strength < 50 ? 0xF0922 : strength < 75 ? 0xF0925 : 0xF0928)
    }

    onActiveChanged: {
        disarm()
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

    // ── "Esquecer", with the second click ──
    property var armed: null
    property double armedAt: 0
    function disarm() {
        armed = null
        disarmTimer.stop()
    }
    function pressForget(net) {
        if (!active || !net || net.known !== true || WifiJoin.busy)
            return
        if (armed !== net) {
            armed = net
            armedAt = Date.now()
            disarmTimer.restart()
            return
        }
        if (Date.now() - armedAt < 300)
            return
        disarm()
        if (net.name === selected)
            selected = ""
        net.forget()
    }
    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.armed = null
    }
    onKeyIndexChanged: disarm()
    // The armed network left the list (or is no longer saved)
    onListChanged: {
        if (armed !== null && !list.shown.some(n => n === armed && n.known === true))
            disarm()
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
        if (it.kind !== "forget")
            disarm()
        if (it.kind === "switch")
            Networking.wifiEnabled = !Networking.wifiEnabled
        else if (it.kind === "forget")
            pressForget(list.shown[it.index])
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
        disarm()
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
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF0928)   // nf-md-wifi_strength_4, as the grid's button
        title: "Wi-Fi"
        detail: root.stateText
        hasSwitch: root.wifiDevice !== null
        checked: Networking.wifiEnabled
        switchFocus: root.keyOn("switch")
        onToggled: {
            root.disarm()
            Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    // Information only: the cable has nothing to configure here
    ListBlock {
        visible: root.wiredDevice !== null && root.wiredDevice.connected

        ListRow {
            icon: String.fromCodePoint(0xF0200)   // nf-md-ethernet
            text: "Cabo"
            detail: "conectado"
        }
    }

    // Why the list is empty, if it is; hidden once networks show up
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: root.wifiDevice === null ? "Sem Wi-Fi neste computador"
            : !Networking.wifiEnabled ? "Wi-Fi desligado"
            : root.all.length === 0 ? "Procurando redes…"
            : root.list.shown.length === 0 && root.query !== "" ? "Nenhuma rede com esse nome" : ""
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // The search, from SEARCH_FROM networks on
    Rectangle {
        Layout.fillWidth: true
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
            font.pointSize: Theme.fontSize - 1
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

    ListHeader {
        visible: root.list.shown.length > 0
        title: "Redes"
        detail: root.query === "" ? `${root.list.shown.length + root.list.hidden} ${root.list.shown.length + root.list.hidden === 1 ? "rede" : "redes"}` : ""
    }
    // The networks, "Mostrar mais" and "Outra rede…": scrolling inside past
    // maxListHeight
    ListBlock {
        id: block
        visible: root.wifiDevice !== null && Networking.wifiEnabled
        maxHeight: root.maxListHeight

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
                    root.disarm()
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

                ListRow {
                    id: row
                    divider: entry.index > 0
                    clickable: true
                    icon: root.signalIcon(entry.strength)
                    iconColor: entry.modelData.connected ? Theme.accentLight : Theme.fg4
                    text: entry.shownName
                    keyFocus: root.keyOn("network", entry.index)
                    detail: entry.modelData.connected ? "conectada"
                          : entry.joining || entry.modelData.stateChanging ? "conectando…"
                          : entry.secured ? String.fromCodePoint(0xF033E) : ""   // nf-md-lock
                    onClicked: entry.press()
                    onKeyFocusChanged: {
                        if (keyFocus)
                            block.reveal(entry)
                    }

                    // On hover (the connected one has it in its details),
                    // with the keyboard on it, or armed, so the list stays
                    // clean
                    ListButton {
                        readonly property bool armed: root.armed === entry.modelData
                        visible: entry.modelData.known && !WifiJoin.busy
                                 && ((row.hovered && !entry.modelData.connected) || root.keyOn("forget", entry.index)
                                     || (armed && !entry.details))
                        compact: true
                        danger: armed
                        text: armed ? "Clique de novo para esquecer" : "Esquecer"
                        keyFocus: root.keyOn("forget", entry.index)
                        onClicked: root.pressForget(entry.modelData)
                    }
                }

                // The last message about this network (fixed words only)
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 4
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
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6
                    visible: entry.details
                    spacing: 4

                    Text {
                        text: `Sinal ${entry.strength}%` + (root.address !== "" ? `   Endereço ${root.address}` : "")
                        textFormat: Text.PlainText
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSizeSmall
                    }
                    RowLayout {
                        spacing: 6
                        ListButton {
                            compact: true
                            text: "Desconectar"
                            onClicked: {
                                root.disarm()
                                root.selected = ""
                                entry.modelData.disconnect()
                            }
                        }
                        ListButton {
                            readonly property bool armed: root.armed === entry.modelData
                            compact: true
                            danger: armed
                            text: armed ? "Clique de novo para esquecer" : "Esquecer"
                            onClicked: root.pressForget(entry.modelData)
                        }
                    }
                }

                // An open network: never joins by itself, and says why
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6
                    visible: entry.confirming
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: "Rede aberta: não entra sozinha nesta rede. Qualquer um pode criar outra com o mesmo nome."
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                    ListButton {
                        compact: true
                        text: "Conectar"
                        onClicked: WifiJoin.confirmOpen(entry.modelData)
                    }
                }

                // A new secured network, or a saved one whose password no
                // longer works
                WifiPassword {
                    id: password
                    Layout.bottomMargin: 6
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

        ListRow {
            id: moreRow
            visible: root.list.hidden > 0
            divider: root.list.shown.length > 0
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF0140)   // nf-md-chevron_down
            text: `Mostrar mais ${root.list.hidden} ${root.list.hidden === 1 ? "rede" : "redes"}`
            keyFocus: root.keyOn("more")
            onClicked: {
                root.disarm()
                root.showAll = true
            }
            onKeyFocusChanged: {
                if (keyFocus)
                    block.reveal(moreRow)
            }
        }

        // A hidden network: its name and password (WifiJoin.joinHidden)
        ListRow {
            id: otherRow
            divider: root.list.shown.length > 0 || root.list.hidden > 0
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF0415)   // nf-md-plus
            text: "Outra rede…"
            keyFocus: root.keyOn("other")
            onClicked: root.toggleOther()
            onKeyFocusChanged: {
                if (keyFocus)
                    block.reveal(otherRow)
            }
        }
        ColumnLayout {
            id: otherForm
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 6
            visible: root.otherOpen && root.active && Networking.wifiEnabled
            spacing: 4

            property string message: ""

            Rectangle {
                Layout.fillWidth: true
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
                    font.pointSize: Theme.fontSize - 1
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
                Layout.leftMargin: 4
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
    }

    // Anything the list does not cover
    ListBlock {
        Layout.topMargin: 4

        ListRow {
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF0493)   // nf-md-cog
            text: "Mais opções…"
            keyFocus: root.keyOn("options")
            onClicked: root.openOptions()
        }
    }
}
