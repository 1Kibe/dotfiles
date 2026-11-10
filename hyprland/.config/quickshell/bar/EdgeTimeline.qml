import QtQuick
import qs.theme
import "edgemotion.js" as EdgeMotion

// The clock of a panel that touches the screen's left or right edge
// (version C, "barra primeiro", Ryan 2026-11-10): open() runs `u` from where
// it is to 1 at a constant pace, close() back to 0 (after closeDelay, for
// rows that leave first) and then says closed(). The panel shows barStep to
// the frame as its edgeStep (the bar stretches that end to the screen's edge
// and squares that corner first) and moves itself by panelStep. Reduce
// motion: the bar changes shape at once and panelStep follows the time
// (the panel fades along it).
Item {
    id: root

    property real u: 0
    property int openDuration: Theme.motionEdgeOpen
    property int closeDuration: Theme.motionEdgeClose
    property int closeDelay: 0

    readonly property real barStep: Theme.reduceMotion ? (u > 0 ? 1 : 0)
                                    : EdgeMotion.barStep(u, Theme.curveDecel, Theme.edgeBarShare)
    readonly property real panelStep: Theme.reduceMotion ? u
                                      : EdgeMotion.panelStep(u, Theme.curveDecel, Theme.edgePanelFrom)
    readonly property bool running: enter.running || leave.running

    signal closed()

    function open() {
        leave.stop()
        enter.restart()
    }
    function close() {
        enter.stop()
        leave.restart()
    }
    function reset() {
        enter.stop()
        leave.stop()
        u = 0
    }

    NumberAnimation {
        id: enter
        target: root
        property: "u"
        to: 1
        duration: Theme.dur(root.openDuration)
        easing.type: Easing.Linear
    }
    SequentialAnimation {
        id: leave
        PauseAnimation { duration: Theme.dur(root.closeDelay) }
        NumberAnimation {
            target: root
            property: "u"
            to: 0
            duration: Theme.dur(root.closeDuration)
            easing.type: Easing.Linear
        }
        ScriptAction { script: root.closed() }
    }
}
