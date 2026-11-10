import QtQuick
import qs.theme

// A few options side by side, the chosen one lit ({ value, label } each)
Rectangle {
    id: root

    property var options: []
    property var value
    signal picked(var value)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    radius: Theme.radius
    color: Theme.bg1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.options

            Rectangle {
                required property var modelData
                readonly property bool chosen: modelData.value === root.value
                width: label.implicitWidth + 20
                height: 24
                radius: Theme.radius - 2
                color: chosen ? Theme.accent : mouse.containsMouse ? Theme.bg2 : Theme.clear

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }
}
