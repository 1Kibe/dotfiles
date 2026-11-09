import QtQuick
import qs.theme

// Horizontal slider 0..1 for the panels: drag or click to set, wheel ±5%.
// Values above 1 (set by another app) show as full and are not raised.
Item {
    id: root

    property real value: 0
    property bool muted: false
    // The slider never sets `value` itself: the owner applies the new value
    // and it comes back through the binding (VolumePanel sets the node volume)
    signal moved(real value)

    // Clamped to 0..1 and rounded to whole percents
    function emit(v) {
        root.moved(Math.round(Math.min(1, Math.max(0, v)) * 100) / 100)
    }

    implicitHeight: 20
    implicitWidth: 160

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.bg2

        Rectangle {
            width: parent.width * Math.min(1, root.value)
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.gray : Theme.accentLight
            // No animation while dragging, so the fill sticks to the pointer
            Behavior on width {
                enabled: !mouse.pressed
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        // Travels the width minus its own, so it never sticks out at the ends
        x: (root.width - width) * Math.min(1, root.value)
        color: Theme.text
        scale: mouse.pressed ? 1.2 : mouse.containsMouse ? 1.1 : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast }
        }
        Behavior on x {
            enabled: !mouse.pressed
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: mouse

        property real wheel: 0   // touchpads send small steps: add them up

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Pointer x over the width gives 0..1; emit() clamps a drag past the ends
        onPressed: event => root.emit(event.x / width)
        onPositionChanged: event => {
            if (pressed)
                root.emit(event.x / width)
        }
        // 120 = one wheel notch = one 5% step
        onWheel: event => {
            wheel += event.angleDelta.y
            while (wheel >= 120) {
                wheel -= 120
                if (root.value < 1)
                    root.emit(root.value + 0.05)
            }
            while (wheel <= -120) {
                wheel += 120
                root.emit(root.value - 0.05)
            }
        }
    }
}
