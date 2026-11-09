import QtQuick
import qs.theme

// On/off switch of a panel header.
Item {
    id: root

    property bool checked: false
    // Only reports the click: the owner flips the real setting and `checked`
    // follows it (NetworkPanel, BluetoothPanel)
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

        // Knob: 14 px in the 20 px track leaves 3 px all around; it slides
        // between the two ends
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
