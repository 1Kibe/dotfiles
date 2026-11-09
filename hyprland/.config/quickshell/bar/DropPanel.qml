import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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
    property bool alignLeft: false     // left edges lined up (buttons on the left of the bar)
    default property alias content: body.data
    property alias underlay: under.data   // behind the content (e.g. a cover)

    // edges: the point of the button the popup hangs from; gravity: the side
    // it grows towards. Default: hang from the bottom-right corner and grow
    // left, so the panel never runs off the right end of the screen.
    anchor.item: button
    anchor.edges: centered ? Edges.Bottom : alignLeft ? Edges.Bottom | Edges.Left : Edges.Bottom | Edges.Right
    anchor.gravity: centered ? Edges.Bottom : alignLeft ? Edges.Bottom | Edges.Right : Edges.Bottom | Edges.Left
    anchor.margins.top: 8
    // Opened by a click: popup grab (keyboard for Esc, click outside closes).
    // Opened by a keybind: no recent click to grab with, so a Hyprland focus
    // grab does the same job (see HyprlandFocusGrab below).
    grabFocus: !ShellState.openedByKey
    color: Theme.clear
    // Shown and hidden only by onOpenChanged and the leave animation, never
    // bound to `open`, so the window outlives the closing animation
    visible: false
    implicitWidth: panelWidth
    // + 12: the body's 6 px margin above and below. The height animates so a
    // panel whose content grows (a list loading) resizes smoothly.
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

    HyprlandFocusGrab {
        active: ShellState.openedByKey && root.open && root.visible
        windows: [root, root.button.QsWindow.window]   // the bar does not count as outside
        onCleared: ShellState.close()
    }

    // Reopening in the middle of a close stops it and starts again from the
    // top; closing in the middle of an open just plays the leave animation
    onOpenChanged: {
        if (open) {
            leave.stop()
            slide.opacity = 0
            shift.y = -10
            visible = true
            enter.restart()
            // Focus on the body so Esc reaches its key handler
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

    // Shorter and with a smaller lift than the entry: closing should feel
    // quicker. The window hides only after the fade ends.
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { target: slide; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { target: shift; property: "y"; to: -6; duration: Theme.animFast; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.visible = false }
    }

    // Clipped so the content sliding in from above is cut at the window's
    // top edge instead of drawing past it
    Item {
        anchors.fill: parent
        clip: true

        // Everything that slides and fades: background, underlay and content
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

            Item {
                id: under
                anchors.fill: parent
            }

            // Children of the panel land here (the `content` alias); its
            // implicit height sizes the window
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
