import QtQuick
import qs.theme

// A line of text, sent on Enter or when it loses focus; Esc puts the stored
// value back. `invalid` paints the border red (the store refused it)
Rectangle {
    id: root

    property string value
    property string placeholder
    property bool invalid: false
    property alias input: edit
    signal accepted(string text)

    implicitWidth: 220
    implicitHeight: 28
    radius: Theme.radius
    color: Theme.bg1
    border.width: 1
    border.color: invalid ? Theme.red : edit.activeFocus ? Theme.accentLight : Theme.clear

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
        font.family: Theme.font
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
            visible: edit.text === "" && !edit.activeFocus
            text: root.placeholder
            color: Theme.gray
            font: edit.font
            verticalAlignment: Text.AlignVCenter
        }
    }
}
