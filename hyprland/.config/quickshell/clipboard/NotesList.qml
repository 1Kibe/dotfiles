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
// It moves as settings/Search does: a note coming in fades in and grows, one
// leaving fades and shrinks, the others slide to their new place (pinning
// too), and the light slides from the chosen row to the next; with reduce
// motion they only fade.
Rectangle {
    id: root

    // The notes listed, in order (notes.js ordered, then filtered)
    property var rows: []
    property string chosen: ""
    signal picked(string nid)
    signal created()
    readonly property int rowHeight: 34

    // The notes by nid: a row reads its note here. The model keeps only the
    // nids, so typing in a note (new rows at every keystroke) changes no row
    // of the model and plays nothing, and the list stays where it was
    // scrolled to
    readonly property var byNid: {
        const m = {}
        for (const n of rows)
            m[n.nid] = n
        return m
    }
    ListModel {
        id: shown
    }
    // The model follows the rows by nid: a note coming, going or moving is an
    // insert, a remove or a move, which the list animates
    function sync() {
        const keys = rows.map(n => n.nid)
        for (let i = shown.count - 1; i >= 0; i--) {
            if (!keys.includes(shown.get(i).nid))
                shown.remove(i)
        }
        for (let i = 0; i < keys.length; i++) {
            let j = -1
            for (let k = i; k < shown.count; k++) {
                if (shown.get(k).nid === keys[i]) {
                    j = k
                    break
                }
            }
            if (j < 0)
                shown.insert(i, { nid: keys[i] })
            else if (j !== i)
                shown.move(j, i, 1)
        }
        list.currentIndex = keys.indexOf(chosen)
        // A note chosen before it reached the model (a new one, one just
        // pinned): it is put on screen now
        if (placeChosen && list.currentIndex >= 0) {
            placeChosen = false
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)
        }
    }
    onRowsChanged: sync()
    Component.onCompleted: sync()

    // The light goes to the chosen row, which stays on screen (the keyboard
    // moves it). Its place is the model's: the rows may already have it while
    // the model does not yet (sync runs after), and then sync puts it on
    // screen
    property bool placeChosen: false
    function modelIndex(nid) {
        for (let i = 0; i < shown.count; i++) {
            if (shown.get(i).nid === nid)
                return i
        }
        return -1
    }
    onChosenChanged: {
        const i = modelIndex(chosen)
        list.currentIndex = i
        placeChosen = i < 0 && chosen !== ""
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
            model: shown
            currentIndex: -1
            // The place a dragged row would go (-1 none): only inside the
            // dragged note's group (pinned or not)
            property int dropAt: -1
            // The row being dragged (the mark goes under the target when
            // it moves down: it lands after it)
            property int dragFrom: -1
            // Where the mark is: it slides from place to place, but shows up
            // in place when a drag starts (markJump: that one move without
            // the slide)
            property int markRow: -1
            property bool markJump: false
            onDropAtChanged: {
                markJump = dropAt >= 0 && markRow < 0
                markRow = dropAt
                markJump = false
            }

            // The chosen row's light, sliding to the next one chosen
            highlight: Rectangle {
                color: Theme.bg1
            }
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.reduceMotion ? 0 : Theme.dur(Theme.animNormal)
            highlightMoveVelocity: -1
            highlightResizeDuration: 0

            add: Transition {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: Theme.dur(Theme.animNormal)
                }
                NumberAnimation {
                    property: "scale"; from: Theme.reduceMotion ? 1 : Theme.noteEnterScale; to: 1
                    duration: Theme.dur(Theme.animNormal)
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"; to: 0
                    duration: Theme.dur(Theme.animFast)
                }
                NumberAnimation {
                    property: "scale"; to: Theme.reduceMotion ? 1 : Theme.noteEnterScale
                    duration: Theme.dur(Theme.animFast)
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveAccel
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"; duration: Theme.reduceMotion ? 0 : Theme.dur(Theme.animNormal)
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                }
                // A row caught mid-entry still ends fully shown
                NumberAnimation { properties: "opacity,scale"; to: 1; duration: Theme.dur(Theme.animFast) }
            }
            move: Transition {
                NumberAnimation {
                    property: "y"; duration: Theme.reduceMotion ? 0 : Theme.dur(Theme.animNormal)
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                }
                NumberAnimation { properties: "opacity,scale"; to: 1; duration: Theme.dur(Theme.animFast) }
            }

            // Where a dragged note would land (in the content, so it scrolls
            // with the rows)
            Rectangle {
                parent: list.contentItem
                z: 3
                visible: list.dropAt >= 0
                y: list.markRow * root.rowHeight
                   + (list.dragFrom >= 0 && list.dragFrom < list.markRow ? root.rowHeight - height : 0)
                width: list.width
                height: 2
                color: Theme.accentLight
                Behavior on y {
                    id: markSlide
                    enabled: !Theme.reduceMotion && !list.markJump
                    NumberAnimation {
                        duration: Theme.dur(Theme.animFast)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                    }
                }
            }

            delegate: Item {
                id: row
                required property string nid
                required property int index
                // The note; the last one seen while the row leaves (it is no
                // longer in the rows then)
                readonly property var live: root.byNid[nid] ?? null
                property var kept: null
                onLiveChanged: {
                    if (live)
                        kept = live
                }
                Component.onCompleted: kept = live
                readonly property var note: live ?? kept ?? ({ nid: "", title: "", body: "", color: 0, pinned: false })
                width: list.width
                height: root.rowHeight
                z: rowMouse.dragging ? 2 : 1

                // Lifted a little while dragged
                Item {
                    id: face
                    anchors.fill: parent
                    scale: rowMouse.dragging && !Theme.reduceMotion ? Theme.noteLift : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.dur(Theme.animFast) }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: rowMouse.containsMouse && row.index !== list.currentIndex ? Theme.veil : Theme.clear
                        Behavior on color {
                            ColorAnimation { duration: Theme.dur(Theme.animFast) }
                        }
                    }
                    Rectangle {
                        x: 10
                        y: 9
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Theme.noteColors[row.note.color % Theme.noteColors.length]
                        Behavior on color {
                            ColorAnimation { duration: Theme.dur(Theme.animNormal) }
                        }
                    }
                    Text {
                        visible: row.note.pinned === true
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
                            text: row.note.title !== "" ? Clean.clean(row.note.title, 120) : "Sem título"
                            textFormat: Text.PlainText
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            color: row.note.title !== "" ? Theme.fg : Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                            font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            text: Notes.preview(row.note.body)
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
                            const at = Math.max(0, Math.min(root.rows.length - 1, Math.floor(p.y / root.rowHeight)))
                            list.dropAt = root.rows[at].pinned === row.note.pinned ? at : -1
                        }
                    }
                    onReleased: {
                        if (dragging && list.dropAt >= 0 && list.dropAt !== row.index)
                            NotesStore.reorder(row.nid, root.rows[list.dropAt].nid)
                        else if (!dragging)
                            root.picked(row.nid)
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
