import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// Quick notes above the clipboard strip: "Notas · N" and "+ Nova nota" on
// top, then the post-its in a grid of 6 per row that scrolls down. A note
// is dragged by its grip to another place; the others make room.
Rectangle {
    id: root

    readonly property int columns: 6

    signal leave()    // a note gave up the keyboard (Esc)

    radius: Theme.stripRadius
    color: Theme.notesFill

    // Clicks here never reach the dark area (which closes the overlay)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.leave()
    }

    RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8

        Text {
            text: `Notas · ${NotesStore.model.count}`
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        Item {
            Layout.fillWidth: true
        }
        Rectangle {
            implicitWidth: addText.implicitWidth + 24
            implicitHeight: 28
            radius: height / 2
            color: addMouse.containsMouse ? Theme.veil : Theme.alpha(Theme.bg1, 0.7)
            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Text {
                id: addText
                anchors.centerIn: parent
                text: "+ Nova nota"
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotesStore.add()
            }
        }
    }

    Text {
        visible: NotesStore.ready && NotesStore.model.count === 0
        anchors.centerIn: grid
        text: "Nenhuma nota ainda"
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 9
        anchors.topMargin: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / root.columns)
        cellHeight: Math.min(cellWidth, Theme.noteSize + 10)
        model: NotesStore.model

        // A new note pops in, a deleted one shrinks away, and the others
        // slide to their new places (also while a note is dragged)
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Theme.animNormal; easing.type: Easing.OutBack }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.85; duration: Theme.animFast; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.animNormal; easing.type: Easing.OutCubic }
            // An item caught in the middle of add/remove ends whole
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: Theme.animNormal }
        }

        delegate: DropArea {
            id: slot

            required property int index
            required property string nid
            required property string title
            required property string body
            required property int color

            width: grid.cellWidth
            height: grid.cellHeight
            onEntered: drag => NotesStore.move(drag.source.slotIndex, slot.index)

            NoteCard {
                id: card

                property int slotIndex: slot.index

                nid: slot.nid
                title: slot.title
                body: slot.body
                colorIndex: slot.color
                width: grid.cellWidth - 10
                height: grid.cellHeight - 10
                anchors.horizontalCenter: slot.horizontalCenter
                anchors.verticalCenter: slot.verticalCenter
                onLeave: root.leave()

                Drag.active: card.grip.drag.active
                Drag.source: card
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: 10

                // While dragged it floats above the grid, free of its slot
                states: State {
                    when: card.grip.drag.active
                    ParentChange {
                        target: card
                        parent: root
                    }
                    AnchorChanges {
                        target: card
                        anchors.horizontalCenter: undefined
                        anchors.verticalCenter: undefined
                    }
                    PropertyChanges {
                        card.z: 10
                        card.opacity: 0.9
                    }
                }

                // A new note opens for typing, at the end of the grid
                Component.onCompleted: {
                    if (NotesStore.focusNid === nid) {
                        NotesStore.focusNid = ""
                        // After the grid has placed the new note, never during
                        // it (moving the view mid-layout crashed Qt)
                        Qt.callLater(() => {
                            grid.positionViewAtEnd()
                            card.edit()
                        })
                    }
                }
            }
        }
    }
}
