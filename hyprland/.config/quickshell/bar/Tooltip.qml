import QtQuick
import Quickshell
import qs.theme

// Tooltip with the bar's background that opens under `target` after Theme.hoverDelay.
PopupWindow {
    id: root

    required property Item target
    property string text
    property bool shown: false

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8
    color: Theme.clear
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 16
    visible: false

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
            text: root.text
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
    }
}
