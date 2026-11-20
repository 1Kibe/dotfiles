import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "notes.js" as Notes
import "../lock/text.js" as Clean

// The Anotações tab's list, a column on the right: "+ Nova anotação" on
// top, then each note (its color's dot, the title and the start of the
// text on one line), the chosen one lit. A click chooses; a drag moves a
// note to another place of its group (NotesStore.reorder). Scrolls inside.
Rectangle {
    id: root

    // The notes listed, in order (notes.js ordered, then filtered)
    property var rows: []
    property string chosen: ""
    signal picked(string nid)
    signal created()

    // The rows change at every keystroke in a note: the list keeps where it
    // was scrolled to instead of jumping back to the top
    onRowsChanged: {
        const y = list.contentY
        list.model = rows
        list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height))
    }
    Component.onCompleted: list.model = rows

    // Keeps the chosen row on screen (the keyboard moves it)
    onChosenChanged: {
        const i = rows.findIndex(n => n.nid === chosen)
        if (i >= 0)
            list.positionViewAtIndex(i, ListView.Contain)
    }

    radius: Theme.radius
    color: Theme.bg

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // "+ Nova anotação"
        Item {
            Layout.fillWidth: true
            implicitHeight: 26

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Theme.radius
                color: newMouse.containsMouse ? Theme.veil : Theme.clear
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                text: "+ Nova anotação"
                textFormat: Text.PlainText
                color: Theme.accentLight
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            MouseArea {
                id: newMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.created()
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.bg1
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // The place a dragged row would go (-1 none): only inside the
            // dragged note's group (pinned or not)
            property int dropAt: -1
            // The row being dragged (the mark goes under the target when
            // it moves down: it lands after it)
            property int dragFrom: -1

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    color: row.modelData.nid === root.chosen ? Theme.bg1 : rowMouse.containsMouse ? Theme.veil : Theme.clear
                }
                // Where a dragged note would land
                Rectangle {
                    visible: list.dropAt === row.index
                    y: list.dragFrom >= 0 && list.dragFrom < row.index ? parent.height - height : 0
                    width: parent.width
                    height: 2
                    color: Theme.accentLight
                }
                Rectangle {
                    x: 10
                    y: 9
                    width: 8
                    height: 8
                    radius: width / 2
                    color: Theme.noteColors[row.modelData.color % Theme.noteColors.length]
                }
                Text {
                    visible: row.modelData.pinned === true
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 5
                    text: String.fromCodePoint(0xF0403)   // nf-md-pin
                    textFormat: Text.PlainText
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSizeSmall
                }
                Column {
                    x: 26
                    y: 3
                    width: parent.width - 26 - 24

                    Text {
                        width: parent.width
                        text: row.modelData.title !== "" ? Clean.clean(row.modelData.title, 120) : "Sem título"
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        color: row.modelData.title !== "" ? Theme.fg : Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: Notes.preview(row.modelData.body)
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSizeSmall
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.bg1
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    property real startY: 0
                    property bool dragging: false
                    // A drag is the row's, not the list's scroll
                    preventStealing: dragging
                    onPressed: event => {
                        startY = event.y
                        dragging = false
                    }
                    onPositionChanged: event => {
                        if (!pressed)
                            return
                        if (!dragging && Math.abs(event.y - startY) > 8) {
                            dragging = true
                            list.dragFrom = row.index
                        }
                        if (dragging) {
                            const p = mapToItem(list.contentItem, event.x, event.y)
                            const at = Math.max(0, Math.min(root.rows.length - 1, Math.floor(p.y / row.height)))
                            list.dropAt = root.rows[at].pinned === row.modelData.pinned ? at : -1
                        }
                    }
                    onReleased: {
                        if (dragging && list.dropAt >= 0 && list.dropAt !== row.index)
                            NotesStore.reorder(row.modelData.nid, root.rows[list.dropAt].nid)
                        else if (!dragging)
                            root.picked(row.modelData.nid)
                        dragging = false
                        list.dropAt = -1
                        list.dragFrom = -1
                    }
                    onCanceled: {
                        dragging = false
                        list.dropAt = -1
                        list.dragFrom = -1
                    }
                }
            }
        }
    }
}
