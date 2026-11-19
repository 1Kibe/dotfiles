import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import qs.bar
import "power.js" as Power

// The control center's power section: lock, log out, suspend, reboot and
// power off from the one fixed table (power.js). Configurações → Energia
// picks which show and which also ask for a second click; reboot and power
// off always do. The first click on one of those only arms it; the second
// on the armed row runs it, unless it comes right after the first (a double
// click). The arm never outlives the section showing: folding it, opening
// another one, closing the center (also by a click outside, the lock or a
// "Manter?" strip), the center moving to another monitor, the choices
// changing, or 5 s without the second click all disarm it.
ColumnLayout {
    id: root

    // This section open in a center that shows (ControlCenter)
    required property bool active
    // The row the keyboard is on (-1 none); Enter is a click (ControlKeys)
    property int keyIndex: -1
    readonly property int keyCount: shown.length
    function pressKey(k) {
        const a = shown[k]
        if (a)
            run(a)
    }

    property string armed: ""   // action waiting for its second click
    property double armedAt: 0
    readonly property var shown: Power.items(Power.ACTIONS, SettingsStore.ready ? SettingsStore.get("powerMenuItems") : null)
    readonly property var confirmIds: SettingsStore.ready ? SettingsStore.get("powerConfirm") : []

    function disarm() {
        armed = ""
        disarmTimer.stop()
    }
    function run(action) {
        if (!active)
            return
        if (Power.needsConfirm(action.id, confirmIds)) {
            if (armed !== action.id) {
                armed = action.id
                armedAt = Date.now()
                disarmTimer.restart()
                return
            }
            if (Date.now() - armedAt < 300)
                return
        }
        disarm()
        // Close the center, then run detached: the command is not tied to
        // the shell, which may go away with the session
        ShellState.close()
        Quickshell.execDetached(action.command)
    }

    onActiveChanged: disarm()
    onShownChanged: disarm()
    onConfirmIdsChanged: disarm()
    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.armed = ""
    }

    Layout.fillWidth: true
    spacing: 2

    Repeater {
        model: root.shown

        PanelRow {
            required property var modelData
            required property int index

            Layout.fillWidth: true
            keyFocus: root.keyIndex === index
            icon: modelData.icon
            text: root.armed === modelData.id ? `Clique de novo para ${modelData.label.toLowerCase()}` : modelData.label
            // The armed row turns red and asks for the second click
            danger: root.armed === modelData.id
            onClicked: root.run(modelData)
        }
    }
}
