import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.bar
import "lists.js" as Lists

// The password field under a network's row (and in the hidden network
// form): hidden by default, the eye to show it, Enter or "Conectar" to hand
// it over. The text only lives in the field: deliver() gets it once and the
// field is wiped in the same call, whatever happens in deliver(). While
// shown, copying and cutting are blocked and the mouse cannot select (a copy
// would land in the clipboard history, on disk); the eye hides it again when
// it is handed over, when the field loses focus and when the field goes
// away. With an error (wrong) the border turns red; the field comes back
// empty, never with the old text. A password that cannot be one is not
// handed over: a fixed line says why.
ColumnLayout {
    id: root

    // Gets the password once; returns whether it was taken
    required property var deliver
    property bool wrong: false
    property string placeholder: "Senha"
    // Esc, Tab, or after handing it over: the keyboard goes back
    signal released()
    signal escaped()

    property bool shown: false
    property string hint: ""

    function focusField() {
        field.forceActiveFocus()
    }
    function clear() {
        field.text = ""
        shown = false
        hint = ""
    }
    function hand() {
        if (field.text === "")
            return
        let ok = false
        try {
            if (!Lists.validPsk(field.text))
                hint = "A senha precisa ter de 8 a 63 caracteres"
            else
                ok = root.deliver(field.text) === true
        } finally {
            field.text = ""
            shown = false
        }
        if (ok) {
            hint = ""
            root.released()
        }
    }

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 4
    spacing: 2

    onVisibleChanged: {
        if (!visible)
            clear()
    }
    Component.onDestruction: field.text = ""

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: Theme.radius
            color: Theme.bg1
            border.width: root.wrong || root.hint !== "" || field.activeFocus ? Theme.focusWidth : 0
            border.color: root.wrong || root.hint !== "" ? Theme.red : Theme.focusRing

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.shown ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                selectByMouse: false
                persistentSelection: false
                maximumLength: 64
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.font
                font.pointSize: Theme.fontSize
                clip: true

                onAccepted: root.hand()
                onActiveFocusChanged: {
                    if (!activeFocus)
                        root.shown = false
                }
                // Shown or not, the password never leaves the field by the
                // keyboard: no copy, no cut
                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0
                    if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)
                            || (ctrl && event.key === Qt.Key_Insert) || (shift && event.key === Qt.Key_Delete)) {
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        root.clear()
                        root.escaped()
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        event.accepted = true
                        root.released()
                    }
                }

                // Placeholder: TextInput has none of its own
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: root.placeholder
                    textFormat: Text.PlainText
                    color: Theme.gray
                    font: field.font
                }
            }
        }
        // nf-md-eye_off / nf-md-eye
        BarItem {
            text: String.fromCodePoint(root.shown ? 0xF0209 : 0xF0208)
            tooltip: root.shown ? "Esconder a senha" : "Mostrar a senha"
            onClicked: {
                root.shown = !root.shown
                field.forceActiveFocus()
            }
        }
        BarItem {
            text: "Conectar"
            onClicked: root.hand()
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: root.hint !== ""
        text: root.hint
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
}
