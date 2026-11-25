import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// The list of the clock's panel: the notifications kept, grouped by app
// (the newest group first), each group with its name, how many and an
// arrow that folds it; each item with its title, up to 2 lines of text,
// the time and an X (out of the list). At most groupMax items per group
// ("e mais N" for the rest); the app's buttons only on the newest item of
// a group. A click on an item opens it like a card (its default action
// and its window). Like the cards: with the pointer over the list, what
// arrives waits (the list does not move under it) until the pointer
// leaves or the user acts here; for 400 ms after the list changes, the
// pointer does nothing; and a click is held from the press, acting only
// on the same item and place. Everything from outside is plain text, cut
// by lines and by height. It scrolls past maxHeight.
Item {
    id: root

    property real maxHeight: 360
    property int groupMax: 5
    // The ones not read when the panel opened (their titles stand out)
    property var fresh: []

    // ── The groups, rebuilt only with the pointer away (or after the
    // user's own action here) ──
    property var groups: []
    // Folded groups by app (a Map: an app's name is never a key of a plain
    // object, where "constructor" or "__proto__" are already taken)
    property var folded: new Map()
    function build() {
        const out = []
        const at = new Map()
        for (const e of NotificationState.entries) {
            if (!at.has(e.appKey)) {
                at.set(e.appKey, out.length)
                out.push({ key: e.appKey, name: e.appName, external: e.external === true, items: [], total: 0 })
            }
            const g = out[at.get(e.appKey)]
            g.total++
            if (g.items.length < groupMax)
                g.items.push(e)
        }
        return out
    }
    function rebuild() {
        groups = build()
    }
    Component.onCompleted: rebuild()
    // (the tests hold it as the pointer would)
    property bool pointerHold: false
    readonly property bool held: hover.hovered || pointerHold
    onHeldChanged: {
        if (!held)
            rebuild()
    }
    Connections {
        target: NotificationState
        function onEntriesChanged() {
            if (!root.held)
                root.rebuild()
        }
    }
    HoverHandler {
        id: hover
    }
    // The pointer waits 400 ms after the list changes
    property bool armed: false
    onGroupsChanged: {
        armed = false
        armTimer.restart()
    }
    Timer {
        id: armTimer
        interval: 400
        onTriggered: root.armed = true
    }

    implicitHeight: groups.length === 0 ? empty.implicitHeight + 24 : Math.min(maxHeight, list.implicitHeight)
    clip: true

    function timeText(ms) {
        const d = new Date(ms)
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }
    function isFolded(key) {
        return folded.get(key) === true
    }
    function fold(key) {
        if (!armed)
            return
        const f = new Map(folded)
        f.set(key, !isFolded(key))
        folded = f
        rebuild()
    }

    // A click held from the press, one per place ("id:index"; index -1:
    // the item, -3: its X, else a button): one place never takes another's
    property var presses: new Map()
    function press(id, index) {
        if (!armed)
            return false
        const p = new Map(presses)
        p.set(id + ":" + index, true)
        presses = p
        return true
    }
    function cancel(id, index) {
        const p = new Map(presses)
        p.delete(id + ":" + index)
        presses = p
    }
    function release(id, index) {
        const held = presses.get(id + ":" + index) === true
        cancel(id, index)
        if (!held || !armed || !NotificationState.entries.some(e => e.id === id))
            return false
        const done = index === -3 ? NotificationState.dismiss(id)
                   : index < 0 ? NotificationState.open(id)
                   : NotificationState.invoke(id, index)
        // The user's own action: the list follows it at once
        if (done)
            rebuild()
        return done
    }

    FontMetrics {
        id: line
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    // Nothing kept
    Text {
        id: empty
        visible: root.groups.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        text: "Nenhuma notificação"
        textFormat: Text.PlainText
        color: Theme.gray
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 8

            Repeater {
                model: root.groups

                ColumnLayout {
                    id: group
                    required property var modelData
                    readonly property bool open: !root.isFolded(modelData.key)
                    Layout.fillWidth: true
                    spacing: 2

                    // The app's name (always in the same place, plain), how many, the fold
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumHeight: line.height
                            clip: true
                            // A shell's name from outside: "externo" after it
                            text: group.modelData.name + (group.modelData.external ? " (externo)" : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.fg4
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSizeSmall
                        }
                        Text {
                            text: String(group.modelData.total)
                            textFormat: Text.PlainText
                            color: Theme.gray
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSizeSmall
                        }
                        Text {
                            text: group.open ? String.fromCodePoint(0xF0140) : String.fromCodePoint(0xF0142)
                            textFormat: Text.PlainText
                            color: Theme.fg4
                            font.family: Theme.font
                            font.pointSize: Theme.fontSizeSmall
                            TapHandler {
                                enabled: root.armed
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: root.fold(group.modelData.key)
                            }
                        }
                    }

                    Repeater {
                        model: group.open ? group.modelData.items : []

                        Rectangle {
                            id: item
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: content.implicitHeight + 12
                            radius: Theme.radius
                            color: Theme.cardFill

                            TapHandler {
                                enabled: root.armed
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onPressedChanged: {
                                    if (pressed)
                                        root.press(item.modelData.id, -1)
                                }
                                onTapped: root.release(item.modelData.id, -1)
                                onCanceled: root.cancel(item.modelData.id, -1)
                            }

                            ColumnLayout {
                                id: content
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.maximumHeight: line.height
                                        clip: true
                                        visible: text !== ""
                                        text: item.modelData.summary
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        color: root.fresh.includes(item.modelData.id) ? Theme.fg : Theme.fg4
                                        font.family: Theme.fontPanels
                                        font.pointSize: Theme.fontSize - 1
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: root.timeText(item.modelData.time)
                                        textFormat: Text.PlainText
                                        color: Theme.gray
                                        font.family: Theme.fontPanels
                                        font.pointSize: Theme.fontSizeSmall
                                    }
                                    // Out of the list (held from the press, like the rest)
                                    Text {
                                        text: String.fromCodePoint(0xF0156)
                                        textFormat: Text.PlainText
                                        color: Theme.fg4
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSizeSmall
                                        TapHandler {
                                            enabled: root.armed
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onPressedChanged: {
                                                if (pressed)
                                                    root.press(item.modelData.id, -3)
                                            }
                                            onTapped: root.release(item.modelData.id, -3)
                                            onCanceled: root.cancel(item.modelData.id, -3)
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.maximumHeight: Math.ceil(2 * line.lineSpacing)
                                    clip: true
                                    visible: text !== ""
                                    text: item.modelData.body
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    color: Theme.fg4
                                    font.family: Theme.fontPanels
                                    font.pointSize: Theme.fontSize - 1
                                }
                                // The buttons: the group's newest item only
                                RowLayout {
                                    visible: item.index === 0 && item.modelData.actions.length > 0
                                    spacing: 6
                                    Repeater {
                                        model: item.index === 0 ? item.modelData.actions : []
                                        Rectangle {
                                            id: button
                                            required property var modelData
                                            Layout.maximumWidth: 120
                                            implicitWidth: label.implicitWidth + 16
                                            implicitHeight: line.height + 8
                                            radius: Theme.radius
                                            color: Theme.bg1
                                            clip: true
                                            TapHandler {
                                                enabled: root.armed
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onPressedChanged: {
                                                    if (pressed)
                                                        root.press(item.modelData.id, button.modelData.index)
                                                }
                                                onTapped: root.release(item.modelData.id, button.modelData.index)
                                                onCanceled: root.cancel(item.modelData.id, button.modelData.index)
                                            }
                                            Text {
                                                id: label
                                                anchors.centerIn: parent
                                                width: Math.min(implicitWidth, parent.width - 16)
                                                height: line.height
                                                text: button.modelData.text
                                                textFormat: Text.PlainText
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                                color: Theme.fg
                                                font.family: Theme.fontPanels
                                                font.pointSize: Theme.fontSize - 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The rest of the group, past groupMax
                    Text {
                        visible: group.open && group.modelData.total > group.modelData.items.length
                        text: `e mais ${group.modelData.total - group.modelData.items.length}`
                        textFormat: Text.PlainText
                        color: Theme.gray
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
