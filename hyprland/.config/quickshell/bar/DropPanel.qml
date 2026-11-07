import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state

// Base of the panels that drop down from the bar: opens under `button`,
// right-aligned to it, with the bar's background. Opening slides the
// content down and fades it in; closing slides it up and fades it out, and
// only then the window hides. Esc closes it with the same animation; a
// click outside closes it right away (the compositor hides the popup).
PopupWindow {
    id: root

    required property Item button
    required property bool open        // from ShellState
    property int panelWidth: Theme.panelWidth
    property bool centered: false      // under the middle of the button
    default property alias content: body.data

    anchor.item: button
    anchor.edges: centered ? Edges.Bottom : Edges.Bottom | Edges.Right
    anchor.gravity: centered ? Edges.Bottom : Edges.Bottom | Edges.Left
    anchor.margins.top: 8
    grabFocus: true   // keyboard (Esc)
    color: Theme.clear
    visible: false
    implicitWidth: panelWidth
    implicitHeight: body.implicitHeight + 12
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Dismissed by the compositor (click outside with the popup grab): no
    // time to animate, just sync the state
    onVisibleChanged: {
        if (!visible && open)
            ShellState.close()
    }

    onOpenChanged: {
        if (open) {
            leave.stop()
            slide.opacity = 0
            shift.y = -10
            visible = true
            enter.restart()
            body.forceActiveFocus()
        } else {
            enter.stop()
            if (visible)
                leave.restart()
        }
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: slide; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { target: slide; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { target: shift; property: "y"; to: -6; duration: Theme.animFast; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.visible = false }
    }

    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: slide
            width: parent.width
            height: parent.height
            opacity: 0
            transform: Translate { id: shift; y: -10 }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.barFill
            }

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2
                focus: true
                Keys.onEscapePressed: ShellState.close()
            }
        }
    }
}
