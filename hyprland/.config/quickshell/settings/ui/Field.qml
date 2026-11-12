import QtQuick
import qs.theme

// A line of text, sent on Enter or when it loses focus; Esc puts the stored
// value back. `invalid` paints the border red (the store refused it). The
// border's color and the placeholder change with a short fade
// (Theme.animFast).
Rectangle {
    id: root

    property string value
    property string placeholder
    property bool invalid: false
    // Paths and name patterns: monospaced, only inside the field
    property bool mono: false
    property alias input: edit
    signal accepted(string text)

    implicitWidth: 220
    implicitHeight: 28
    radius: Theme.radius
    color: Theme.bg1
    border.width: 1
    border.color: invalid ? Theme.red : edit.activeFocus ? Theme.accentLight : Theme.alpha(Theme.accentLight, 0)
    Behavior on border.color {
        ColorAnimation { duration: Theme.dur(Theme.animFast) }
    }

    onValueChanged: {
        if (!edit.activeFocus)
            edit.text = value
    }
    Component.onCompleted: edit.text = value

    TextInput {
        id: edit
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        font.family: root.mono ? Theme.monoFont : Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
        onAccepted: root.accepted(text)
        onActiveFocusChanged: {
            if (!activeFocus && text !== root.value)
                root.accepted(text)
        }
        Keys.onEscapePressed: event => {
            text = root.value
            focus = false
            event.accepted = true
        }

        Text {
            anchors.fill: parent
            opacity: edit.text === "" && !edit.activeFocus ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.dur(Theme.animFast) }
            }
            text: root.placeholder
            color: Theme.gray
            font: edit.font
            verticalAlignment: Text.AlignVCenter
        }
    }
}
