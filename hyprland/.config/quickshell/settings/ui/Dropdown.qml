import QtQuick
import QtQuick.Layouts
import qs.theme

// A choice among many ({ value, label } each), opened in place under the
// button. With `multiple`, the value is a list and each option is checked
// on or off (the bar's items before the reorderable list of T5). A long list
// (the fonts) scrolls inside, at most `rows` lines tall, opening on the
// chosen one. A list of choices too long for the button reads as a count
// ("3 de 5", "Todos"). Always Theme.dropdownWidth wide (Theme.dropdownPairWidth
// in a paired row's column), whatever the row around it: no page sets a
// width of its own. A long choice is cut with "…" on the button; the open
// list grows for it, to the left, up to Theme.dropdownMaxWidth and never
// past the window's left edge. Opened near the bottom of the page, the page
// scrolls so the whole list shows.
//
// Motion (Theme tokens, times the speed): the list unrolls and fades in
// (animNormal) and rolls back faster (animFast), its options kept until it
// is closed; the arrow turns; hover and the chosen option change color
// (animFast). Reduce motion: the list only fades and the arrow just flips.
ColumnLayout {
    id: root

    property var options: []
    property var value
    property bool multiple: false
    property bool expanded: false
    property int rows: 8
    // In a paired row's column (KeyRow, through KeyControl)
    property bool paired: false
    readonly property int buttonWidth: paired ? Theme.dropdownPairWidth : Theme.dropdownWidth
    signal picked(var value)

    Layout.preferredWidth: buttonWidth
    Layout.maximumWidth: buttonWidth
    implicitWidth: buttonWidth

    spacing: 4

    function has(v) {
        return multiple ? (Array.isArray(value) && value.includes(v)) : value === v
    }
    readonly property var chosenLabels: options.filter(o => has(o.value)).map(o => o.label)
    readonly property string joined: chosenLabels.length === 0 ? (multiple ? "Nenhum" : "—") : chosenLabels.join(", ")
    readonly property string summary: {
        if (!multiple || chosenLabels.length < 2 || joinedMetrics.advanceWidth <= summaryText.width)
            return joined
        return chosenLabels.length === options.length ? "Todos" : `${chosenLabels.length} de ${options.length}`
    }
    TextMetrics {
        id: joinedMetrics
        text: root.joined
        font: summaryText.font
    }

    // 0 = closed, 1 = open; the options stay while it is above 0
    property real reveal: expanded ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.dur(root.expanded ? Theme.animNormal : Theme.animFast)
            easing.type: root.expanded ? Easing.OutCubic : Easing.InCubic
        }
    }

    Rectangle {
        Layout.preferredWidth: root.buttonWidth
        implicitHeight: 28
        radius: Theme.radius
        color: mouse.containsMouse ? Theme.bg2 : Theme.bg1
        Behavior on color {
            ColorAnimation { duration: Theme.dur(Theme.animFast) }
        }

        Text {
            id: summaryText
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.summary
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            rotation: root.expanded ? 180 : 0
            color: Theme.fg4
            font.family: Theme.fontPanels
            Behavior on rotation {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // The open list's width: the longest choice, at least the button's, at
    // most the ceiling and the room to the window's left edge
    FontMetrics {
        id: itemMetrics
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
    property real listWidth: buttonWidth
    function measure() {
        let wanted = buttonWidth
        for (const o of options)
            wanted = Math.max(wanted, itemMetrics.advanceWidth(`󰄬  ${o.label}`) + 24)
        const right = holder.mapToItem(null, holder.width, 0).x
        const room = Math.max(buttonWidth, right - 8)
        listWidth = Math.round(Math.min(wanted, Theme.dropdownMaxWidth, room))
    }
    onExpandedChanged: if (expanded) measure()
    // Fully open: the page around it scrolls so the whole list shows
    onRevealChanged: if (reveal === 1 && expanded) showTimer.restart()
    // After the layout around it took the list's height in
    Timer {
        id: showTimer
        interval: 50
        onTriggered: root.showWhole()
    }
    function showWhole() {
        let f = root.parent
        while (f && !(f.contentY !== undefined && f.contentHeight !== undefined && f.height !== undefined))
            f = f.parent
        if (!f || !f.contentItem)
            return
        const bottom = holder.mapToItem(f.contentItem, 0, holder.height).y
        const top = root.mapToItem(f.contentItem, 0, 0).y
        if (bottom > f.contentY + f.height)
            f.contentY = Math.min(Math.max(0, f.contentHeight - f.height), Math.min(top, bottom - f.height + 8))
    }

    // In the row's layout the list takes the button's width; drawn over it,
    // wider to the left when a choice is long
    Item {
        id: holder
        Layout.preferredWidth: root.buttonWidth
        Layout.preferredHeight: list.shownHeight
        // Its own condition (the list's `visible` follows this one)
        visible: list.count > 0 && root.reveal > 0
        z: 10
        Rectangle {
            anchors.fill: list
            anchors.margins: -2
            radius: Theme.radius
            color: Theme.bg1
            visible: list.width > root.buttonWidth
        }
        ListView {
            id: list
            readonly property real fullHeight: Math.min(count, root.rows) * 28 - (count > 0 ? 2 : 0)
            // Unrolls with `reveal`; reduce motion: full height, fading only
            readonly property real shownHeight: Theme.reduceMotion ? fullHeight : fullHeight * root.reveal
            anchors.right: parent.right
            width: root.listWidth
            height: shownHeight
            opacity: root.reveal
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.expanded || root.reveal > 0 ? root.options : []
            onCountChanged: {
                if (count > 0) {
                    const i = root.options.findIndex(o => root.has(o.value))
                    if (i >= 0)
                        positionViewAtIndex(i, ListView.Center)
                }
            }

            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool chosen: root.has(modelData.value)
                width: list.width
                height: 26
                radius: Theme.radius
                color: itemMouse.containsMouse ? Theme.veil : chosen ? Theme.alpha(Theme.accent, 0.35) : Theme.alpha(Theme.accent, 0)
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: `${item.chosen ? "󰄬" : "  "}  ${item.modelData.label}`
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.expanded
                    onClicked: {
                        // Closing empties the list, and this item goes with it:
                        // pick first, close last
                        if (!root.multiple) {
                            const dropdown = root
                            dropdown.picked(item.modelData.value)
                            dropdown.expanded = false
                            return
                        }
                        const list = Array.isArray(root.value) ? root.value.slice() : []
                        const i = list.indexOf(item.modelData.value)
                        if (i >= 0)
                            list.splice(i, 1)
                        else
                            list.push(item.modelData.value)
                        root.picked(list)
                    }
                }
            }
        }
    }
}
