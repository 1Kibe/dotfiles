import QtQuick
import QtQuick.Layouts
import qs.theme

// A button of the control center's grid: icon, name, a state line and an
// optional second line. With a list it has an arrow that turns while its
// section is folded out (ToggleTile is the same without the arrow, lit while
// on). The keyboard's ring (keyFocus) is a border of the Theme.
Rectangle {
    id: root

    property string icon
    property string label
    property string status
    property string detail
    property bool hasArrow: true
    property bool open: false     // its section folded out
    property bool on: false       // switched on: lit
    property bool warn: false     // something waiting (updates): icon and state in yellow
    property bool keyFocus: false

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.tileHeight
    radius: Theme.radius
    color: on ? Theme.tileOn : mouse.containsMouse ? Theme.veil : Theme.tileFill
    Behavior on color {
        ColorAnimation { duration: Theme.dur(Theme.animFast) }
    }
    border.width: keyFocus ? Theme.focusWidth : 0
    border.color: Theme.focusRing

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        Text {
            textFormat: Text.PlainText
            text: root.icon
            color: root.warn ? Theme.yellow : root.on ? Theme.accentLight : Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize + 3
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                text: root.label
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                Layout.fillWidth: true
                visible: root.status !== ""
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                text: root.status
                color: root.warn ? Theme.yellow : Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSizeSmall
            }
            Text {
                Layout.fillWidth: true
                visible: root.detail !== ""
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                text: root.detail
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSizeSmall
            }
        }
        // nf-md-chevron_down, half a turn while open
        Text {
            visible: root.hasArrow
            textFormat: Text.PlainText
            text: String.fromCodePoint(0xF0140)
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            rotation: root.open ? 180 : 0
            Behavior on rotation {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
            }
        }
    }
}
