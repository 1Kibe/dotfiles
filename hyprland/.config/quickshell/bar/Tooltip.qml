import QtQuick
import Quickshell
import qs.theme

// Tooltip with the bar's background that opens past `target` after
// Theme.hoverDelay: under it, or above it with the bar on the bottom edge.
PopupWindow {
    id: root

    required property Item target
    property string text
    // Hover state from the owner (BarItem, SystemStatus, Workspaces); the
    // window follows it after the delay, with a fade
    property bool shown: false

    anchor.item: target
    anchor.edges: Theme.barAtBottom ? Edges.Top : Edges.Bottom
    anchor.gravity: Theme.barAtBottom ? Edges.Top : Edges.Bottom
    anchor.margins.top: Theme.barAtBottom ? 0 : 8
    anchor.margins.bottom: Theme.barAtBottom ? 8 : 0
    color: Theme.clear
    // 8 px of padding on each side of the label
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 16
    visible: false

    // Shown: wait Theme.hoverDelay, so a pointer passing by does not flash it.
    // Hidden: fade out first, the window hides at the end. Empty text never opens.
    onShownChanged: {
        if (shown && text !== "") {
            fadeOut.stop()
            delay.restart()
        } else {
            delay.stop()
            if (visible)
                fadeOut.restart()
        }
    }

    Timer {
        id: delay
        interval: Theme.hoverDelay
        onTriggered: {
            // Map the window fully transparent, then fade the content in
            pane.opacity = 0
            root.visible = true
            fadeIn.restart()
        }
    }

    NumberAnimation { id: fadeIn; target: pane; property: "opacity"; to: 1; duration: Theme.animFast; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: pane; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
        ScriptAction { script: root.visible = false }
    }

    // The fades act on this item; the window itself only shows or hides
    Item {
        id: pane
        anchors.fill: parent
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.barFill
        }

        Text {
            id: label
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.text
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
    }
}
