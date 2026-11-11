import QtQuick
import QtQuick.Layouts
import qs.theme

// A panel that grows from the screen's bottom edge (or from the top one,
// `edge`), centered (Print's annotation bar). The mirror of the panels that
// hang from the top bar: the same shape (AttachedShape, edge "bottom"), with
// its concave corners against the screen's edge, the same curve and times, and
// the content sliding up from inside the edge while it fades in. Its place is
// fixed: put it in a full screen item.
Item {
    id: root

    required property bool open
    // The screen's edge it grows from: "bottom", or "top" (the same panel,
    // mirrored: with the bar on the bottom edge Print's annotation bar goes up)
    property string edge: "bottom"
    readonly property bool fromTop: edge === "top"
    property real panelWidth: Theme.panelWidth
    default property alias content: body.data

    // 0 = rolled down into the edge, 1 = open
    property real progress: 0
    // Its outline (SVG path), at (x, y): Print's overlay keeps its veil out
    // of it, so it reads like the bar (capture/CaptureOverlay)
    readonly property alias outline: shape.outline

    visible: false
    width: shape.implicitWidth
    height: shape.implicitHeight
    x: Math.round(parent ? parent.width / 2 - width / 2 : 0)
    y: fromTop || !parent ? 0 : parent.height - height

    // The content plus its 6 px margin on both sides
    readonly property real bodyHeight: body.implicitHeight + 12

    onOpenChanged: {
        if (open) {
            leave.stop()
            if (!visible)
                progress = 0
            visible = true
            enter.restart()
        } else {
            enter.stop()
            if (visible)
                leave.restart()
        }
    }
    Component.onCompleted: {
        if (open) {
            visible = true
            enter.restart()
        }
    }

    NumberAnimation {
        id: enter
        target: root
        property: "progress"
        to: 1
        duration: Theme.dur(Theme.motionPanelOpen)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveDecel
    }
    SequentialAnimation {
        id: leave
        NumberAnimation {
            target: root
            property: "progress"
            to: 0
            duration: Theme.dur(Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveAccel
        }
        ScriptAction {
            script: {
                root.visible = false
                root.progress = 0
            }
        }
    }

    AttachedShape {
        id: shape
        anchors.fill: parent
        edge: root.fromTop ? "top" : "bottom"
        bodyWidth: root.panelWidth
        bodyHeight: root.bodyHeight
        progress: root.progress
    }

    // The visible part of the body, from the edge up: clicks on it never
    // reach what is under the panel (a stroke, a new selection)
    MouseArea {
        x: shape.bodyX
        y: root.fromTop ? 0 : root.height - shape.visibleHeight
        width: root.panelWidth
        height: shape.visibleHeight
        acceptedButtons: Qt.AllButtons
    }

    // The content, its top at the top of the visible part, so it rises from
    // inside the edge as the body grows. A plain clip: the content keeps a
    // 6 px margin, so it never reaches the rounded corners (and the panel
    // can be drawn without Quickshell, in the tests)
    Item {
        x: shape.bodyX
        y: root.fromTop ? 0 : root.height - shape.visibleHeight
        width: root.panelWidth
        height: shape.visibleHeight
        clip: true

        // From the top edge the content comes down: its bottom at the bottom
        // of the visible part
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.fromTop ? parent.height - implicitHeight - 6 : 6
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 2
            opacity: root.progress
        }
    }
}
