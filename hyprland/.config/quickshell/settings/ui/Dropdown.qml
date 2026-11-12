import QtQuick
import QtQuick.Layouts
import qs.theme

// A choice among many ({ value, label } each), opened in place under the
// button. With `multiple`, the value is a list and each option is checked
// on or off (the bar's items before the reorderable list of T5). A long list
// (the fonts) scrolls inside, at most `rows` lines tall, opening on the
// chosen one. A list of choices too long for the button reads as a count
// ("3 de 5", "Todos"), never cut with "…". 220 px wide, or the width it
// is given (a paired row's column).
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
    signal picked(var value)

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
        Layout.preferredWidth: 220
        Layout.fillWidth: true
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

    ListView {
        id: list
        readonly property real fullHeight: Math.min(count, root.rows) * 28 - (count > 0 ? 2 : 0)
        Layout.preferredWidth: 220
        Layout.fillWidth: true
        // Unrolls with `reveal`; reduce motion: full height, fading only
        Layout.preferredHeight: Theme.reduceMotion ? fullHeight : fullHeight * root.reveal
        visible: count > 0 && root.reveal > 0
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
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: `${item.chosen ? "󰄬" : "  "}  ${item.modelData.label}`
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
