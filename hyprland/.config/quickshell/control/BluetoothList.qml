import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The Bluetooth list, in the control center's Bluetooth section and in the
// bar's Bluetooth panel: the switch (BluetoothPower, by rfkill), the paired
// devices on top (the connected first), "Por perto" (found by "Procurar",
// scrolling inside past maxListHeight, the ones with no name behind
// "+ N sem nome") and "Mais opções…". Names from outside go through
// lists.js and show as plain text.
//
// The list keeps what outlives a card (the Repeaters make the cards again
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

    component SectionLabel: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    component Card: DeviceCard {
        required property var modelData
        required property int index
        attempt: root.attemptDevice === modelData ? root.attemptKind : ""
        error: root.errorDevice === modelData ? root.error : ""
        onClicked: root.pressDevice(modelData)
    }

    Layout.fillWidth: true
    spacing: 2

    // Header: the switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 34

        Text {
            Layout.fillWidth: true
            text: "Bluetooth"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        PanelSwitch {
            visible: root.available
            checked: root.powered
            onToggled: root.toggleSwitch()
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

    // Why the list is empty, or the switch's failure (fixed words only)
    SectionLabel {
        Layout.bottomMargin: 6
        visible: text !== ""
        text: !root.available ? "Sem Bluetooth neste computador"
            : BluetoothPower.error !== "" ? BluetoothPower.error
            : BluetoothPower.busy ? (BluetoothPower.wantOn ? "Ligando…" : "Desligando…")
            : !root.powered ? "Bluetooth desligado" : ""
        color: BluetoothPower.error !== "" && root.available ? Theme.red : Theme.gray
    }

    // Paired, always on top
    SectionLabel {
        visible: root.list.mine.length > 0
        text: "Seus aparelhos"
    }
    Repeater {
        model: root.list.mine
        Card {
            canForget: modelData.paired === true
            forgetArmed: root.armed === modelData
            keyFocus: root.keyOn("mine", index)
            forgetFocus: root.keyOn("forget", index)
            onForgetClicked: root.pressForget(modelData)
        }
    }

    // Nearby: searched on demand
    RowLayout {
        visible: root.powered
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 6
        Layout.topMargin: 6

        Text {
            Layout.fillWidth: true
            text: "Por perto"
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            visible: root.scanning
            text: "󰑓"
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            // Still with animations off or reduced motion (a zero length
            // would loop with no pause)
            RotationAnimation on rotation {
                running: root.scanning && root.active && Theme.speed > 0 && !Theme.reduceMotion
                from: 0
                to: 360
                duration: Theme.dur(Theme.spinnerPeriod)
                loops: Animation.Infinite
            }
        }
        BarItem {
            text: root.scanning ? "Parar" : "Procurar"
            keyFocus: root.keyOn("scan")
            onClicked: root.toggleScan()
        }
    }
    // BlueZ keeps the devices an earlier search found, so they stay listed
    // after "Parar" until they drop off
    Flickable {
        id: flick
        visible: root.powered && root.list.near.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(near.implicitHeight, root.maxListHeight)
        contentWidth: width
        contentHeight: near.implicitHeight
        interactive: near.implicitHeight > root.maxListHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: near
            width: flick.width
            spacing: 2

            Repeater {
                model: root.list.near
                Card {
                    id: nearCard
                    keyFocus: root.keyOn("near", index)
                    onKeyFocusChanged: {
                        if (keyFocus) {
                            if (y < flick.contentY)
                                flick.contentY = y
                            else if (y + height > flick.contentY + flick.height)
                                flick.contentY = y + height - flick.height
                        }
                    }
                }
            }
        }
    }
    PanelRow {
        visible: root.powered && root.list.unnamed > 0
        icon: ""
        text: `+ ${root.list.unnamed} sem nome`
        keyFocus: root.keyOn("unnamed")
        onClicked: root.revealUnnamed()
    }
    SectionLabel {
        visible: root.scanning && root.list.near.length === 0 && root.list.unnamed === 0
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
        keyFocus: root.keyOn("options")
        onClicked: root.openOptions()
    }
}
