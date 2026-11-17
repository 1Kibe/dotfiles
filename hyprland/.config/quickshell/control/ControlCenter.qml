import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar

// The control center: drops down from its button and continues the bar's
// right end. Its sections come in the next steps; for now a title only.
AttachedPanel {
    id: root

    panelWidth: Theme.controlWidth
    side: "right"

    // It never stays over the lock screen nor under a "Manter?" strip (which
    // takes the keyboard); ShellState.controlAllowed keeps it from opening
    // again while they last
    Connections {
        target: LockState
        function onWantedChanged() {
            if (LockState.wanted)
                ShellState.closeControl()
        }
        function onLockedChanged() {
            if (LockState.locked)
                ShellState.closeControl()
        }
    }
    Connections {
        target: MonitorsApply
        function onPendingChanged() {
            if (MonitorsApply.pending)
                ShellState.closeControl()
        }
    }
    Connections {
        target: KeyboardLayout
        function onPendingChanged() {
            if (KeyboardLayout.pending)
                ShellState.closeControl()
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Configurações rápidas"
        textFormat: Text.PlainText
        color: Theme.text
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
}
