import QtQuick
import qs.theme

// A label of the bar: icon and/or text, with an optional tooltip.
// Clickable items get a light veil on hover and a springy scale.
Item {
    id: root

    property string text
    property color textColor: Theme.text
    property string tooltip
    property bool clickable: true
    property int maxWidth: 0      // > 0: cut the text with "…" at this width

    signal clicked(int button)
    signal scrolled(int steps)    // +1 per wheel notch up, -1 per notch down

    implicitWidth: label.width + 12
    implicitHeight: Theme.itemHeight

    scale: !clickable ? 1 : mouse.pressed ? 0.96 : mouse.containsMouse ? 1.04 : 1
    Behavior on scale {
        SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.005 }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.clickable && mouse.containsMouse ? Theme.veil : Theme.clear
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: root.maxWidth > 0 ? Math.min(implicitWidth, root.maxWidth) : implicitWidth
        elide: Text.ElideRight
        text: root.text
        color: root.textColor
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    MouseArea {
        id: mouse

        property real wheel: 0   // touchpads send small steps: add them up to whole notches

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            if (root.clickable)
                root.clicked(event.button)
        }
        onWheel: event => {
            wheel += event.angleDelta.y
            while (wheel >= 120) {
                wheel -= 120
                root.scrolled(1)
            }
            while (wheel <= -120) {
                wheel += 120
                root.scrolled(-1)
            }
        }
    }

    Tooltip {
        target: root
        text: root.tooltip
        shown: mouse.containsMouse && !mouse.pressed
    }
}
