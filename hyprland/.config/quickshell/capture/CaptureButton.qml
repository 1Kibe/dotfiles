import QtQuick
import QtQuick.Layouts
import qs.theme

// A button of the capture bars: an icon and an optional short label.
// The chosen one has a light background; a disabled one is dimmed.
Rectangle {
    id: root

    property string icon
    property string label
    property bool active: false
    property bool enabled: true
    property bool danger: false
    property string hint                    // shown under the bar on hover
    readonly property bool hovered: mouse.containsMouse

    signal pressed()

    implicitWidth: Math.max(Theme.captureButtonWidth, row.implicitWidth + 16)
    implicitHeight: Theme.captureButtonHeight
    radius: Theme.radius
    color: danger ? Theme.alpha(Theme.red, mouse.containsMouse ? 0.95 : 0.8)
         : active ? Theme.activeFill
         : mouse.containsMouse && enabled ? Theme.veil : Theme.clear
    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.enabled ? Theme.text : Theme.bg2
            font.family: Theme.font
            font.pointSize: Theme.fontSize + 1
        }
        Text {
            visible: root.label !== ""
            text: root.label
            color: !root.enabled ? Theme.bg2 : root.active || root.danger ? Theme.text : Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled)
                root.pressed()
        }
    }
}
