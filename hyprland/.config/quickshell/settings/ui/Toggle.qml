import QtQuick
import qs.theme

// On/off switch. It never sets `checked` itself: the owner stores the new
// value and it comes back through the binding
Item {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 36
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.bg2
        Behavior on color {
            ColorAnimation { duration: Theme.dur(Theme.animFast) }
        }
    }
    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: Theme.text
        Behavior on x {
            NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
