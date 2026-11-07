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
            delay.restart()
        } else {
            delay.stop()
            visible = false
        }
    }

    Timer {
        id: delay
        interval: Theme.hoverDelay
        onTriggered: root.visible = true
    }

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
