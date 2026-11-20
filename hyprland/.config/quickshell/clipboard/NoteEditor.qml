import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.control

// The note in focus, on the Anotações tab: its title and text written in
// place, on its own color; under them the colors, "Copiar", "Fixar" and
// "Apagar" (the second click deletes). The text is loaded when the note
// changes, never bound to the store while typing (the cursor stays put).
// Esc in the text goes back to the list (leave). Shown as plain text.
Rectangle {
    id: root

    // The note shown ({ nid, title, body, color, pinned }); null: none
    property var note: null
    // "Apagar" waiting for its second click (the tab's, also armed by Del)
    property bool deleteArmed: false
    signal leave()
    signal deleteClicked()
    // Ctrl+N and Ctrl+P also while writing
    signal createRequested()
    signal pinRequested()
    function ctrlKey(event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return
        if (event.key === Qt.Key_N) {
            root.createRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            root.pinRequested()
            event.accepted = true
        }
    }

    readonly property string nid: note ? note.nid : ""
    // The keyboard is in the title or the text (NotesTab keeps this note
    // listed meanwhile, so the keys never reach another one)
    readonly property bool editing: titleField.activeFocus || bodyField.activeFocus
    onNidChanged: {
        titleField.text = note ? note.title : ""
        bodyField.text = note ? note.body : ""
    }
    function focusTitle() {
        titleField.forceActiveFocus()
    }
    function focusBody() {
        bodyField.forceActiveFocus()
        bodyField.cursorPosition = bodyField.length
    }

    radius: Theme.radius
    color: note ? Theme.alpha(Theme.noteColors[note.color % Theme.noteColors.length], 0.16) : Theme.bg

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        TextInput {
            id: titleField
            Layout.fillWidth: true
            color: Theme.fg
            selectionColor: Theme.alpha(Theme.accentLight, 0.4)
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.weight: Font.Medium
            maximumLength: 120
            clip: true
            onTextEdited: NotesStore.update(root.nid, "title", text)
            Keys.onEscapePressed: root.leave()
            Keys.onPressed: event => root.ctrlKey(event)
            Keys.onReturnPressed: root.focusBody()
            Keys.onTabPressed: root.focusBody()

            Text {
                visible: titleField.text === ""
                text: "Título"
                textFormat: Text.PlainText
                color: Theme.gray
                font: titleField.font
            }
        }
        Flickable {
            id: bodyFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: bodyField.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            TextEdit {
                id: bodyField
                width: bodyFlick.width
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                color: Theme.fg2
                selectionColor: Theme.alpha(Theme.accentLight, 0.4)
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
                onTextChanged: {
                    if (activeFocus)
                        NotesStore.update(root.nid, "body", text)
                }
                onCursorRectangleChanged: {
                    const r = cursorRectangle
                    if (r.y < bodyFlick.contentY)
                        bodyFlick.contentY = r.y
                    else if (r.y + r.height > bodyFlick.contentY + bodyFlick.height)
                        bodyFlick.contentY = r.y + r.height - bodyFlick.height
                }
                Keys.onEscapePressed: root.leave()
                Keys.onPressed: event => root.ctrlKey(event)

                Text {
                    visible: bodyField.text === ""
                    text: "Escreva aqui"
                    textFormat: Text.PlainText
                    color: Theme.gray
                    font: bodyField.font
                }
            }
        }

        // The colors and the note's actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Theme.noteColors.length

                Rectangle {
                    required property int index
                    implicitWidth: 12
                    implicitHeight: 12
                    radius: width / 2
                    color: Theme.noteColors[index]
                    border.width: root.note && root.note.color === index ? 2 : 0
                    border.color: Theme.fg

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotesStore.setColor(root.nid, index)
                            root.leave()
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ListButton {
                compact: true
                text: "Copiar"
                onClicked: {
                    NotesStore.copy(root.nid)
                    root.leave()
                }
            }
            ListButton {
                compact: true
                text: root.note && root.note.pinned ? "Desafixar" : "Fixar"
                onClicked: {
                    NotesStore.togglePin(root.nid)
                    root.leave()
                }
            }
            ListButton {
                compact: true
                danger: root.deleteArmed
                text: root.deleteArmed ? "Clique de novo para apagar" : "Apagar"
                onClicked: root.deleteClicked()
            }
        }
    }
}
