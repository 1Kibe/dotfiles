import QtQuick
import qs.theme

// A text button (with an optional Nerd Font icon)
Rectangle {
    id: root

    property string text
    property string icon
    property bool danger: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: Theme.radius
    color: danger ? Theme.danger : mouse.containsMouse ? Theme.bg2 : Theme.bg1

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon !== "" ? `${root.icon}  ${root.text}` : root.text
        color: root.danger ? Theme.red : Theme.text
        font.family: Theme.font
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
