import QtQuick
import qs.theme
import "edgemotion.js" as EdgeMotion

// The clock of a panel that touches the screen's left or right edge, the
// bar's part first and the panel's after it: open() runs `u` from where
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
    // The bar's corner: along the bar's part of the time at an even pace,
    // eased at both ends (barStep rushes at the end of a closing)
    readonly property real barCorner: Theme.reduceMotion ? barStep : EdgeMotion.cornerStep(u / Theme.edgeBarShare)
    readonly property real panelStep: Theme.reduceMotion ? u
                                      : EdgeMotion.panelStep(u, Theme.curveDecel, Theme.edgePanelFrom)
    // The panel's part of the time, linear (0 when it starts, 1 at the end):
    // what grows or shrinks evenly along it (its corners), not with the
    // panel's eased step, which closes with a rush at the end
    readonly property real panelTime: Theme.reduceMotion ? u : Math.max(0, Math.min(1, (u - Theme.edgePanelFrom) / (1 - Theme.edgePanelFrom)))
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
