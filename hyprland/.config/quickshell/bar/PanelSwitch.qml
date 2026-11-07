import QtQuick
import qs.theme

// On/off switch of a panel header.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 36
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.bg2
        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: Theme.text
            Behavior on x {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
