import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// A post-it: title and text edited in place (saved by NotesStore), and at
// the bottom color, copy and delete (delete asks for a second click). The
// grip on top drags the note to another place (NotesGrid). Esc leaves the
// note and gives the keyboard back to the search.
Rectangle {
    id: root

    required property string nid
    required property string title
    required property string body
    required property int colorIndex
    property alias grip: gripMouse         // drag handle, used by NotesGrid
    property bool armed: false             // delete waiting for its second click
    readonly property bool hovered: hover.hovered
    readonly property bool editing: titleInput.activeFocus || bodyInput.activeFocus

    signal leave()

    function edit() {
        titleInput.forceActiveFocus()
    }

    radius: 8
    color: Theme.noteColors[colorIndex]
    Behavior on color {
        ColorAnimation { duration: Theme.animNormal }
    }
    onHoveredChanged: {
        if (!hovered)
            armed = false
    }

    HoverHandler {
        id: hover
    }

    // Text fields start from the stored text and only write back: a binding
    // would move the cursor on every save
    Component.onCompleted: {
        titleInput.text = title
        bodyInput.text = body
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 4
        spacing: 2

        // Grip: drag from here
        Item {
            Layout.fillWidth: true
            implicitHeight: 14

            Text {
                anchors.centerIn: parent
                text: "󰇘"
                color: Theme.alpha(Theme.noteInk, root.hovered ? 0.6 : 0.25)
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            MouseArea {
                id: gripMouse
                anchors.fill: parent
                drag.target: root
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            }
        }

        TextInput {
            id: titleInput
            Layout.fillWidth: true
            clip: true
            color: Theme.noteInk
            selectionColor: Theme.alpha(Theme.noteInk, 0.3)
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
            onTextEdited: NotesStore.update(root.nid, "title", text)
            Keys.onEscapePressed: root.leave()
            Keys.onTabPressed: bodyInput.forceActiveFocus()
            Keys.onReturnPressed: bodyInput.forceActiveFocus()

            Text {
                visible: titleInput.text === "" && !titleInput.activeFocus
                text: "Título"
                color: Theme.alpha(Theme.noteInk, 0.45)
                font: titleInput.font
            }
        }

        Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: bodyInput.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: bodyInput
                width: scroller.width
                wrapMode: TextEdit.Wrap
                color: Theme.noteInk
                selectionColor: Theme.alpha(Theme.noteInk, 0.3)
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
                onTextChanged: {
                    if (activeFocus)
                        NotesStore.update(root.nid, "body", text)
                }
                // Keep the caret visible while typing
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > scroller.contentY + scroller.height)
                        scroller.contentY = cursorRectangle.y + cursorRectangle.height - scroller.height
                    else if (cursorRectangle.y < scroller.contentY)
                        scroller.contentY = cursorRectangle.y
                }
                Keys.onEscapePressed: root.leave()

                Text {
                    visible: bodyInput.text === "" && !bodyInput.activeFocus
                    text: "Escreva aqui"
                    color: Theme.alpha(Theme.noteInk, 0.45)
                    font: bodyInput.font
                }
            }
        }

        // Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            opacity: root.hovered || root.editing ? 1 : 0.35
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }

            Text {
                Layout.fillWidth: true
                visible: root.armed
                text: "Clique de novo"
                color: Theme.noteInk
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
                font.bold: true
            }
            Item {
                Layout.fillWidth: true
                visible: !root.armed
            }

            component Action: Rectangle {
                id: action

                required property string icon
                property bool danger: false
                signal pressed()

                implicitWidth: 24
                implicitHeight: 24
                radius: 6
                color: danger ? Theme.alpha(Theme.red, 0.85)
                              : area.containsMouse ? Theme.alpha(Theme.noteInk, 0.15) : Theme.clear

                Text {
                    anchors.centerIn: parent
                    text: action.icon
                    color: action.danger ? Theme.text : Theme.noteInk
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: action.pressed()
                }
            }

            Action {
                icon: "󰏘"
                onPressed: NotesStore.cycleColor(root.nid)
            }
            Action {
                icon: "󰆏"
                onPressed: NotesStore.copy(root.nid)
            }
            Action {
                icon: "󰅖"
                danger: root.armed
                onPressed: {
                    if (root.armed)
                        NotesStore.remove(root.nid)
                    else
                        root.armed = true
                }
            }
        }
    }
}
