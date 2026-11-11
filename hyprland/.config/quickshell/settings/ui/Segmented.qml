import QtQuick
import qs.theme

// A few options side by side, the chosen one lit ({ value, label } each).
// The light slides from the old choice to the new one (Theme.animNormal);
// with reduce motion it fades over instead, and with speed 0 it jumps.
// Hover tints the others briefly (Theme.animFast).
Rectangle {
    id: root

    property var options: []
    property var value
    signal picked(var value)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    radius: Theme.radius
    color: Theme.bg1

    readonly property int chosenIndex: options.findIndex(o => o.value === value)
    // The chosen option's item (the Repeater's count makes it follow a
    // new list)
    readonly property Item chosenItem: repeater.count > 0 && chosenIndex >= 0 ? repeater.itemAt(chosenIndex) : null

    // The light, under the labels. Reduce motion: it does not travel; the
    // old one fades out and the new one in
    Rectangle {
        id: light
        visible: root.chosenItem !== null && !Theme.reduceMotion
        x: root.chosenItem ? row.x + root.chosenItem.x : 0
        y: row.y
        width: root.chosenItem ? root.chosenItem.width : 0
        height: 24
        radius: Math.max(0, Theme.radius - 2)
        color: Theme.accent
        Behavior on x {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.dur(Theme.animFast) }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            id: repeater
            model: root.options

            Rectangle {
                id: option
                required property var modelData
                required property int index
                readonly property bool chosen: index === root.chosenIndex
                width: label.implicitWidth + 20
                height: 24
                radius: Math.max(0, Theme.radius - 2)
                color: chosen && Theme.reduceMotion ? Theme.accent
                     : !chosen && mouse.containsMouse ? Theme.bg2 : Theme.alpha(Theme.bg2, 0)
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: option.modelData.label
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(option.modelData.value)
                }
            }
        }
    }
}
