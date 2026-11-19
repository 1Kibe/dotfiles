import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The Bluetooth list, in the control center's Bluetooth section and in the
// bar's Bluetooth panel: the header with the state and the switch
// (BluetoothPower, by rfkill), "Pareados" (the connected first), "Por
// perto" ("Procurar" on top, scrolling inside past maxListHeight, the ones
// with no name behind "+ N sem nome") and "Mais opções…", with the
// sections' common parts (ListHeader, ListBlock, ListRow). Each device is
// one row: its icon by type, the name, and on the right its state or what
// a click does ("80% · conectado", "Conectar", "Parear"). Names from
// outside go through lists.js and show as plain text.
//
// The list keeps what outlives a row (the Repeaters make the rows again
// whenever a device moves between the lists): the one attempt to connect
// or pair, with its message, and the "Esquecer" armed. Pairing from here
// marks the device as trusted, so it reconnects by itself next time.
// "Esquecer" is only for a paired device and asks for a second click: the
// first arms it, the second (not within 300 ms, a double click) forgets the
// device object itself, disconnecting it first; 5 s, another device, a
// click elsewhere, the keyboard moving, or the list closing disarm it.
// The search for devices runs only on "Procurar" and stops when the list
// closes (the section, the center, the lock). Every opening starts clean.
ColumnLayout {
    id: root

    // The list showing (its panel or section open)
    required property bool active
    // The most "Por perto" takes before scrolling inside
    property real maxListHeight: 240
    // The item the control center's keyboard is on (-1 none); see keyItems
    property int keyIndex: -1

    readonly property var adapter: BluetoothPower.adapter
    readonly property bool available: BluetoothPower.available
    readonly property bool powered: BluetoothPower.powered
    // The adapter itself checked in each binding: it can still read null for
    // a moment while BluetoothPower's state already changed
    readonly property bool scanning: adapter !== null && adapter.discovering
    readonly property var list: Lists.bluetoothList(powered && adapter !== null ? adapter.devices.values : [], { showUnnamed: showUnnamed })

    // The state in the header and on the grid's button: a count at most,
    // never a device's name
    readonly property string stateText: Lists.bluetoothSummary({
        available: available,
        powered: powered,
        connected: powered && adapter !== null ? adapter.devices.values.filter(d => d.connected).length : 0
    })
    // A device's row, on the right
    function status(d) {
        return Lists.deviceStatus({
            error: errorDevice === d ? error : "",
            attempt: attemptDevice === d ? attemptKind : "",
            pairing: d.pairing === true,
            connecting: d.state === BluetoothDeviceState.Connecting,
            disconnecting: d.state === BluetoothDeviceState.Disconnecting,
            connected: d.connected === true,
            paired: d.paired === true,
            battery: d.batteryAvailable === true ? Math.round(d.battery * 100) : -1
        })
    }

    property bool showUnnamed: false
    // This list started the search (another one, or bluetui, may have)
    property bool startedScan: false

    onActiveChanged: {
        if (!active)
            stopScan()
        showUnnamed = false
        disarm()
        error = ""
        errorDevice = null
        BluetoothPower.clearError()
    }
    onPoweredChanged: {
        if (!powered) {
            startedScan = false
            showUnnamed = false
            disarm()
        }
    }
    onKeyIndexChanged: disarm()
    // A bar going away while this list searches: the search stops with it
    Component.onDestruction: stopScan()

    function toggleScan() {
        if (!active || !powered || adapter === null)
            return
        disarm()
        if (scanning) {
            adapter.discovering = false
            startedScan = false
        } else {
            adapter.discovering = true
            startedScan = true
        }
    }
    function stopScan() {
        if (startedScan && scanning)
            adapter.discovering = false
        startedScan = false
    }

    // ── The attempt: one at a time ──
    property var attemptDevice: null
    property string attemptKind: ""     // "connect" or "pair"
    // A connect fails only after BlueZ went through Connecting: right after
    // connect() the state can still read Disconnected
    property bool sawConnecting: false
    property string error: ""
    property var errorDevice: null

    // A click (or Enter) on a device
    function pressDevice(device) {
        disarm()
        if (!device || !active)
            return
        if (device.connected) {
            device.disconnect()
            return
        }
        if (attemptDevice !== null)
            return
        start(device, device.paired ? "connect" : "pair")
    }
    function start(device, kind) {
        error = ""
        errorDevice = null
        attemptDevice = device
        attemptKind = kind
        sawConnecting = false
        attemptTimer.restart()
        if (kind === "pair")
            device.pair()
        else
            device.connect()
    }
    function endAttempt() {
        attemptTimer.stop()
        const d = attemptDevice
        attemptDevice = null
        attemptKind = ""
        sawConnecting = false
        return d
    }
    function fail(message) {
        const d = endAttempt()
        error = message
        errorDevice = d
    }
    // Paired: trusted, then connect
    function pairedNow() {
        if (attemptKind !== "pair" || attemptDevice === null || !attemptDevice.paired)
            return
        attemptDevice.trusted = true
        start(attemptDevice, "connect")
    }
    // BlueZ sends no failure signal: the attempt follows the device's
    // properties, and 20 s with no end is a failure
    Connections {
        target: root.attemptDevice
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            if (root.attemptDevice && root.attemptDevice.connected)
                root.endAttempt()
        }
        function onStateChanged() {
            if (root.attemptKind !== "connect" || !root.attemptDevice)
                return
            if (root.attemptDevice.state === BluetoothDeviceState.Connecting)
                root.sawConnecting = true
            else if (root.attemptDevice.state === BluetoothDeviceState.Disconnected && root.sawConnecting)
                root.fail("Não conectou")
        }
        function onPairedChanged() {
            root.pairedNow()
        }
        function onPairingChanged() {
            if (root.attemptKind !== "pair" || !root.attemptDevice || root.attemptDevice.pairing)
                return
            if (root.attemptDevice.paired)
                root.pairedNow()
            else
                root.fail("Não pareou")
        }
    }
    Timer {
        id: attemptTimer
        interval: 20000
        onTriggered: {
            const pairing = root.attemptKind === "pair"
            if (pairing && root.attemptDevice)
                root.attemptDevice.cancelPair()
            root.fail(pairing ? "Não pareou" : "Não conectou")
        }
    }

    // ── "Esquecer", with the second click ──
    property var armed: null
    property double armedAt: 0
    property var forgetting: null
    property int forgetTimeoutMs: 5000   // a test shortens it

    function disarm() {
        armed = null
        disarmTimer.stop()
    }
    function pressForget(device) {
        if (!device || !active || device.paired !== true)
            return
        if (armed !== device) {
            armed = device
            armedAt = Date.now()
            disarmTimer.restart()
            return
        }
        if (Date.now() - armedAt < 300)
            return
        disarm()
        forget(device)
    }
    // The device object from the list itself, never an address
    function forget(device) {
        error = ""
        errorDevice = null
        if (attemptDevice === device)
            endAttempt()
        forgetting = device
        forgetWait.interval = forgetTimeoutMs
        if (device.connected) {
            device.disconnect()
            forgetWait.restart()
        } else {
            device.forget()
            forgetCheck.interval = forgetTimeoutMs
            forgetCheck.restart()
        }
    }
    function forgetNow() {
        forgetWait.stop()
        if (!forgetting)
            return
        forgetting.forget()
        forgetCheck.interval = forgetTimeoutMs
        forgetCheck.restart()
    }
    Connections {
        target: root.forgetting
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            if (root.forgetting && !root.forgetting.connected && forgetWait.running)
                root.forgetNow()
        }
    }
    // Still connected after the wait: forget anyway (BlueZ drops the link)
    Timer {
        id: forgetWait
        onTriggered: root.forgetNow()
    }
    // A forgotten device leaves the list (its object goes away); one still
    // paired did not go
    Timer {
        id: forgetCheck
        onTriggered: {
            const d = root.forgetting
            root.forgetting = null
            if (d && d.paired) {
                root.error = "Não deu para esquecer o aparelho"
                root.errorDevice = d
            }
        }
    }
    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.armed = null
    }
    // The armed device left the paired ones
    onListChanged: {
        if (armed !== null && !list.mine.includes(armed))
            disarm()
    }

    // ── The control center's keyboard ──
    readonly property var keyItems: Lists.bluetoothKeys({ available: available, powered: powered, list: list })
    readonly property int keyCount: keyItems.length
    function keyOn(kind, i) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind && (i === undefined || it.index === i)
    }
    // Enter on an item: the same as a click (a held key never presses twice)
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "switch")
            toggleSwitch()
        else if (it.kind === "mine")
            pressDevice(list.mine[it.index])
        else if (it.kind === "forget")
            pressForget(list.mine[it.index])
        else if (it.kind === "scan")
            toggleScan()
        else if (it.kind === "near")
            pressDevice(list.near[it.index])
        else if (it.kind === "unnamed")
            revealUnnamed()
        else if (it.kind === "options")
            openOptions()
    }
    function toggleSwitch() {
        disarm()
        BluetoothPower.toggle()
    }
    function revealUnnamed() {
        disarm()
        showUnnamed = true
    }
    function openOptions() {
        ShellState.close()
        // Anything the list does not cover; the window class matches a
        // float rule in hypr/modules/rules.lua
        Quickshell.execDetached(["kitty", "--class", "bluetui", "bluetui"])
    }

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF00AF)   // nf-md-bluetooth, as the grid's button
        title: "Bluetooth"
        detail: root.stateText
        hasSwitch: root.available
        checked: root.powered
        switchFocus: root.keyOn("switch")
        onToggled: root.toggleSwitch()
    }

    // Why the list is empty, or the switch's failure (fixed words only)
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: text !== ""
        text: !root.available ? "Sem Bluetooth neste computador"
            : BluetoothPower.error !== "" ? BluetoothPower.error
            : BluetoothPower.busy ? (BluetoothPower.wantOn ? "Ligando…" : "Desligando…")
            : !root.powered ? "Bluetooth desligado" : ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: BluetoothPower.error !== "" && root.available ? Theme.red : Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // Paired, always on top
    ListHeader {
        visible: root.list.mine.length > 0
        title: "Pareados"
        detail: {
            const n = root.list.mine.filter(d => d.connected).length
            return n === 1 ? "1 conectado" : n > 1 ? `${n} conectados` : ""
        }
    }
    ListBlock {
        visible: root.list.mine.length > 0

        Repeater {
            model: root.list.mine

            ListRow {
                id: mineRow
                required property var modelData
                required property int index
                readonly property bool armed: root.armed === modelData

                divider: index > 0
                clickable: true
                icon: Lists.deviceIcon(modelData.icon)
                iconColor: modelData.connected ? Theme.accentLight : Theme.fg4
                text: Lists.deviceLabel(modelData)
                detail: root.status(modelData)
                detailColor: root.errorDevice === modelData && root.error !== "" ? Theme.red : Theme.fg4
                keyFocus: root.keyOn("mine", index)
                onClicked: root.pressDevice(modelData)

                // Only for a paired device, while the pointer or the
                // keyboard is on the row, or while armed
                ListButton {
                    visible: mineRow.modelData.paired === true
                             && (mineRow.hovered || mineRow.keyFocus || root.keyOn("forget", mineRow.index) || mineRow.armed)
                    compact: true
                    danger: mineRow.armed
                    text: mineRow.armed ? "Clique de novo para esquecer" : "Esquecer"
                    keyFocus: root.keyOn("forget", mineRow.index)
                    onClicked: root.pressForget(mineRow.modelData)
                }
            }
        }
    }

    // Nearby: searched on demand; BlueZ keeps the devices an earlier search
    // found, so they stay listed after "Parar" until they drop off
    ListHeader {
        visible: root.powered
        title: "Por perto"
        detail: root.scanning ? "procurando…"
              : root.list.near.length === 1 ? "1 aparelho"
              : root.list.near.length > 1 ? `${root.list.near.length} aparelhos` : ""
    }
    ListBlock {
        id: nearBlock
        visible: root.powered
        maxHeight: root.maxListHeight

        ListRow {
            action: true
            clickable: true
            icon: String.fromCodePoint(root.scanning ? 0xF04DB : 0xF0450)   // nf-md-stop, nf-md-refresh
            text: root.scanning ? "Parar de procurar" : "Procurar aparelhos"
            keyFocus: root.keyOn("scan")
            onClicked: root.toggleScan()
        }
        Repeater {
            model: root.list.near

            ListRow {
                id: nearRow
                required property var modelData
                required property int index

                divider: true
                clickable: true
                icon: Lists.deviceIcon(modelData.icon)
                text: Lists.deviceLabel(modelData)
                detail: root.status(modelData)
                detailColor: root.errorDevice === modelData && root.error !== "" ? Theme.red : Theme.fg4
                keyFocus: root.keyOn("near", index)
                onClicked: root.pressDevice(modelData)
                onKeyFocusChanged: {
                    if (keyFocus)
                        nearBlock.reveal(nearRow)
                }
            }
        }
        ListRow {
            id: unnamedRow
            visible: root.list.unnamed > 0
            divider: true
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF0208)   // nf-md-eye
            text: `+ ${root.list.unnamed} sem nome`
            keyFocus: root.keyOn("unnamed")
            onClicked: root.revealUnnamed()
            onKeyFocusChanged: {
                if (keyFocus)
                    nearBlock.reveal(unnamedRow)
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
