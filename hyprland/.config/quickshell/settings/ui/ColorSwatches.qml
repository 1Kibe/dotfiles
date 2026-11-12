import QtQuick
import qs.theme
import qs.state
import "../appearance.js" as Appearance

// The accent's choices as dots, each in the color it gives (the same pair
// the shell applies, settings/appearance.js), the chosen one with a ring.
// Hover shows the color's name; with the keyboard focus, the arrows move
// the choice. Like the other controls it only sends `picked`: the stored
// value comes back by binding. The ring moves with a short fade
// (Theme.animFast).
Item {
    id: root

    property var options: []
    property var value
    signal picked(var value)

    readonly property int size: 18
    implicitWidth: row.implicitWidth
    implicitHeight: size + 8
    activeFocusOnTab: true

    function colorOf(v) {
        return Appearance.accentPair(v, SettingsApply.palette()).accent
    }
    readonly property int chosenIndex: options.findIndex(o => o.value === value)
    Keys.onLeftPressed: if (chosenIndex > 0) picked(options[chosenIndex - 1].value)
    Keys.onRightPressed: if (chosenIndex >= 0 && chosenIndex < options.length - 1) picked(options[chosenIndex + 1].value)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: root.options

            Item {
                id: swatch
                required property var modelData
                required property int index
                readonly property bool chosen: index === root.chosenIndex
                width: root.size + 6
                height: root.size + 6

                // The ring of the chosen one
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.alpha(Theme.text, 0)
                    border.width: 2
                    border.color: swatch.chosen ? Theme.text : Theme.alpha(Theme.text, 0)
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.dur(Theme.animFast) }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: root.size
                    height: root.size
                    radius: width / 2
                    color: root.colorOf(swatch.modelData.value)
                    scale: mouse.containsMouse && !Theme.reduceMotion ? 1.1 : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.forceActiveFocus()
                        root.picked(swatch.modelData.value)
                    }
                }
                // The color's name, above
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 4
                    width: tip.implicitWidth + 12
                    height: tip.implicitHeight + 6
                    radius: Math.max(0, Theme.radius - 2)
                    color: Theme.bg1
                    opacity: mouse.containsMouse ? 1 : 0
                    visible: opacity > 0
                    z: 2
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.dur(Theme.animFast) }
                    }
                    Text {
                        id: tip
                        anchors.centerIn: parent
                        text: swatch.modelData.label
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
}
