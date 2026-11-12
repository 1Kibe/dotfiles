import QtQuick
import qs.theme

// A text button (with an optional Nerd Font icon); hover changes its color
// with a short fade (Theme.animFast)
Rectangle {
    id: root

    property string text
    property string icon
    // danger: armed, waiting for the second click; destructive: an action
    // that removes something (red text and icon even before)
    property bool danger: false
    property bool destructive: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: Theme.radius
    color: danger ? Theme.danger : mouse.containsMouse ? Theme.bg2 : Theme.bg1
    Behavior on color {
        ColorAnimation { duration: Theme.dur(Theme.animFast) }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon !== "" ? `${root.icon}  ${root.text}` : root.text
        color: root.danger || root.destructive ? Theme.red : Theme.text
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
