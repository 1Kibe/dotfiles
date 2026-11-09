import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Super+V: full screen layer on the focused monitor. The screen dims, the
// clipboard strip rises from the bottom and the quick notes fade in above
// it; a click on the dark area, Esc or Super+V again closes it. It takes
// the keyboard while open.
PanelWindow {
    id: root

    // Kept on screen while the closing animation runs
    property bool closing: false
    readonly property bool shown: ClipboardStore.open

    // The monitor Super+V was pressed on; the first one if it is gone
    screen: Quickshell.screens.find(s => s.name === ClipboardStore.openOn) ?? Quickshell.screens[0]
    visible: shown || closing
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Covers the bar too and never pushes windows aside
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    // Exclusive so every key reaches the search; dropped as soon as it
    // starts closing, so the keyboard goes back without waiting for the animation
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            // Also when reopened mid-close: stop it and start from the hidden pose
            leave.stop()
            closing = false
            shade.opacity = 0
            notes.opacity = 0
            drop.y = -12
            rise.y = strip.height + 20
            // Empty search, history tab, first card, keyboard in the search
            strip.reset()
            enter.restart()
        } else {
            enter.stop()
            // The window stays visible until leave ends
            closing = true
            leave.restart()
        }
    }

    // Opening: shade and notes fade in, the notes drop 12 px into place and
    // the strip rises from below the edge (its height + 20 also hides the margin)
    ParallelAnimation {
        id: enter
        NumberAnimation { target: shade; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: notes; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: drop; property: "y"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Closing: the same moves, shorter and eased in; then the window hides
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { target: shade; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { target: notes; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { target: drop; property: "y"; to: -8; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { target: rise; property: "y"; to: strip.height + 20; duration: Theme.animFast; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closing = false }
    }

    // Dark area: a click closes
    Rectangle {
        id: shade
        anchors.fill: parent
        color: Theme.dim
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: ClipboardStore.close()
        }
    }

    NotesGrid {
        id: notes
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: strip.top
        anchors.margins: Theme.gap
        anchors.topMargin: Theme.barHeight + Theme.gap   // the bar stays readable above
        opacity: 0
        transform: Translate { id: drop }   // slides down a little while it fades in
        // Esc in a note, or a click on an empty spot: the search takes the keyboard back
        onLeave: strip.focusSearch()
    }

    ClipStrip {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.gap
        transform: Translate { id: rise }
    }
}
