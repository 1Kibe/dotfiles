import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// The list of the clock's panel: the notifications kept, grouped by app
// (the newest group first), each group with its name, how many and an
// arrow that folds it; each item with its title, up to 2 lines of text,
// the time and an X (out of the list). The app's buttons only on the
// newest item of a group. A click on an item opens it like a card (its
// default action and its window); like the cards, a click is held from
// the press and acts only on the same item. Everything from outside is
// plain text, cut by lines and by height. It scrolls past maxHeight.
Item {
    id: root

    property real maxHeight: 360
    property var folded: ({})
    readonly property var groups: {
        const out = []
        const at = {}
        for (const e of NotificationState.entries) {
            if (at[e.appKey] === undefined) {
                at[e.appKey] = out.length
                out.push({ key: e.appKey, name: e.appName, items: [] })
            }
            out[at[e.appKey]].items.push(e)
        }
        return out
    }

    implicitHeight: groups.length === 0 ? empty.implicitHeight + 24 : Math.min(maxHeight, list.implicitHeight)
    clip: true

    function timeText(ms) {
        const d = new Date(ms)
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }
    // A click held from the press (index -1: the item; else a button)
    property int pressedId: -1
    property int pressedIndex: -2
    function press(id, index) {
        pressedId = id
        pressedIndex = index
    }
    function release(id, index) {
        const same = pressedId === id && pressedIndex === index && NotificationState.entries.some(e => e.id === id)
        pressedId = -1
        pressedIndex = -2
        if (!same)
            return false
        if (index < 0)
            NotificationState.open(id)
        else
            NotificationState.invoke(id, index)
        return true
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
                    readonly property bool open: root.folded[modelData.key] !== true
                    Layout.fillWidth: true
                    spacing: 2

                    // The app's name (always in the same place, plain), how many, the fold
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumHeight: line.height
                            clip: true
                            text: group.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.fg4
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSizeSmall
                        }
                        Text {
                            text: String(group.modelData.items.length)
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
                                onTapped: {
                                    const f = Object.assign({}, root.folded)
                                    f[group.modelData.key] = group.open
                                    root.folded = f
                                }
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
                                onPressedChanged: {
                                    if (pressed)
                                        root.press(item.modelData.id, -1)
                                }
                                onTapped: root.release(item.modelData.id, -1)
                                onCanceled: root.pressedId = -1
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
                                        color: item.modelData.read ? Theme.fg4 : Theme.fg
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
                                    // Out of the list
                                    Text {
                                        text: String.fromCodePoint(0xF0156)
                                        textFormat: Text.PlainText
                                        color: Theme.fg4
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSizeSmall
                                        TapHandler {
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: NotificationState.dismiss(item.modelData.id)
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
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onPressedChanged: {
                                                    if (pressed)
                                                        root.press(item.modelData.id, button.modelData.index)
                                                }
                                                onTapped: root.release(item.modelData.id, button.modelData.index)
                                                onCanceled: root.pressedId = -1
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
                }
            }
        }
    }
}
