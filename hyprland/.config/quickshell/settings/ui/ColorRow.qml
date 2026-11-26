import QtQuick
import qs.theme
import "../../theme/palettes.js" as Palettes

// One color of the theme editor: a square that opens the picker, the name
// with a small hint, the contrast label when it has one (green with ✓ when
// it passes, yellow "abaixo de N" when not) and the hex field. A hex that is
// not "#rrggbb" puts the color back.
Item {
    id: root

    property string label
    property string hint
    property string value: ""
    // { text, ok, least } or null
    property var contrast: null
    signal edited(string hex)
    signal openPicker(Item square)

    implicitHeight: 40

    Rectangle {
        id: square
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 6
        color: root.value
        border.width: 1
        border.color: Theme.bg2
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPicker(square)
        }
    }
    Column {
        x: square.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - hexField.width - badge.width - 16
        Text {
            width: parent.width
            text: root.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            width: parent.width
            visible: root.hint !== ""
            text: root.hint
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.fg4
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
    }
    Rectangle {
        id: badge
        anchors.right: hexField.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.contrast !== null
        width: visible ? badgeText.implicitWidth + 12 : 0
        height: 20
        radius: 10
        color: root.contrast && root.contrast.ok ? Theme.alpha(Theme.green, 0.2) : Theme.alpha(Theme.yellow, 0.2)
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: !root.contrast ? "" : root.contrast.ok ? `${root.contrast.text} ✓`
                  : `${root.contrast.text} · abaixo de ${String(root.contrast.least).replace(".", ",")}`
            textFormat: Text.PlainText
            color: root.contrast && root.contrast.ok ? Theme.green : Theme.yellow
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
    }
    Field {
        id: hexField
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 86
        mono: true
        value: root.value
        input.maximumLength: 7
        onAccepted: t => {
            const h = t.trim().toLowerCase()
            if (Palettes.isHex(h))
                root.edited(h)
            else
                input.text = root.value
        }
    }
}
