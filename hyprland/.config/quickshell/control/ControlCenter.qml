import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar

// The control center: drops down from its button and continues the bar's
// right end. The top line (battery, settings, power), and under it the
// section folded out (one at a time, ShellState.controlSection): for now the
// power section.
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

    // The monitor this center belongs to (its bar's)
    readonly property string monitorName: button && button.monitorName !== undefined ? button.monitorName : ""
    // The most a section grows: a part of the screen's height (it scrolls
    // inside past that)
    readonly property real listMax: frame && frame.screen ? frame.screen.height * Theme.controlListMax : 400

    ControlTop {
        monitorName: root.monitorName
    }
    Accordion {
        open: root.open && ShellState.controlSection === "power"
        maxHeight: root.listMax

        PowerList {
            active: root.open && ShellState.controlSection === "power"
        }
    }
}
