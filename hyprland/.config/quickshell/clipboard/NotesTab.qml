import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.control
import "notes.js" as Notes

// The clipboard drawer's Anotações tab: the note in focus on the left
// (NoteEditor), ready to write in, and the list in a column on the right
// (NotesList, Theme.notesListWidth). The search of the drawer filters the
// list by title and text; when the note in focus leaves the filter, the
// first one listed takes its place. With no note: "Nenhuma anotação" and
// "Nova anotação". Keys (from the drawer's search, the list's keyboard):
// ↑/↓ choose, Enter goes to the text, Ctrl+N creates, Ctrl+P pins and
// unpins, Del arms the delete and a second Del deletes; Esc in the note
// comes back to the list (leave).
Item {
    id: root

    property string query: ""
    property bool active: false
    // The keyboard back to the drawer's search (the list's keys)
    signal leave()
    // The search emptied (a new note must not be filtered out)
    signal clearSearch()

    readonly property var rows: {
        NotesStore.revision
        return Notes.filtered(Notes.ordered(NotesStore.list()), query)
    }
    property string chosen: ""
    readonly property string shown: Notes.keepChosen(rows, chosen)
    readonly property var note: rows.find(n => n.nid === shown) ?? null
    // The note shown becomes the chosen one after this round (written at
    // once, it would feed back into `shown` in the same evaluation)
    onShownChanged: {
        Qt.callLater(() => {
            if (root.shown !== "" && root.shown !== root.chosen)
                root.chosen = root.shown
        })
        disarm()
    }
    onActiveChanged: disarm()

    // ── "Apagar": the first click (or Del) arms, the second deletes ──
    property string armed: ""
    function disarm() {
        armed = ""
        disarmTimer.stop()
    }
    function pressDelete() {
        if (!note)
            return
        if (armed !== note.nid) {
            armed = note.nid
            disarmTimer.restart()
            return
        }
        disarm()
        NotesStore.remove(note.nid)
    }
    Timer {
        id: disarmTimer
        interval: Theme.armTimeout
        onTriggered: root.armed = ""
    }

    function choose(nid) {
        chosen = nid
    }
    function step(d) {
        if (rows.length === 0)
            return
        const i = rows.findIndex(n => n.nid === shown)
        choose(rows[Math.max(0, Math.min(rows.length - 1, i + d))].nid)
    }
    // A new note: the search is emptied first, so the note is listed and
    // chosen, and its title takes the keyboard
    function create() {
        if (query !== "")
            clearSearch()
        NotesStore.add()
    }
    // A new note: chosen, the keyboard in its title
    Connections {
        target: NotesStore
        function onFocusNidChanged() {
            if (NotesStore.focusNid === "" || !root.active)
                return
            root.chosen = NotesStore.focusNid
            NotesStore.focusNid = ""
            Qt.callLater(() => editor.focusTitle())
        }
    }

    // A key from the drawer's search; true when taken
    function key(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        if (event.key === Qt.Key_Up)
            step(-1)
        else if (event.key === Qt.Key_Down)
            step(1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && note)
            editor.focusBody()
        else if (ctrl && event.key === Qt.Key_N)
            create()
        else if (ctrl && event.key === Qt.Key_P && note)
            NotesStore.togglePin(note.nid)
        else if (event.key === Qt.Key_Delete && query === "")
            pressDelete()
        else
            return false
        return true
    }

    // No note at all
    ColumnLayout {
        anchors.centerIn: parent
        visible: NotesStore.ready && NotesStore.model.count === 0
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nenhuma anotação"
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        ListButton {
            Layout.alignment: Qt.AlignHCenter
            text: "Nova anotação"
            onClicked: root.create()
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: NotesStore.model.count > 0
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NoteEditor {
                id: editor
                anchors.fill: parent
                visible: root.note !== null
                note: root.note
                deleteArmed: root.note !== null && root.armed === root.note.nid
                onLeave: root.leave()
                onDeleteClicked: root.pressDelete()
                onCreateRequested: root.create()
                onPinRequested: {
                    if (root.note)
                        NotesStore.togglePin(root.note.nid)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.note === null
                text: "Nada encontrado"
                textFormat: Text.PlainText
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
        }
        NotesList {
            Layout.preferredWidth: Theme.notesListWidth
            Layout.fillHeight: true
            rows: root.rows
            chosen: root.shown
            onPicked: nid => {
                root.choose(nid)
                root.leave()
            }
            onCreated: root.create()
        }
    }
}
