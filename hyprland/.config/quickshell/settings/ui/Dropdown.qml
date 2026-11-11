import QtQuick
import QtQuick.Layouts
import qs.theme

// A choice among many ({ value, label } each), opened in place under the
// button. With `multiple`, the value is a list and each option is checked
// on or off (the bar's items before the reorderable list of T5). A long list
// (the fonts) scrolls inside, at most `rows` lines tall, opening on the
// chosen one
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
    readonly property string summary: {
        const chosen = options.filter(o => has(o.value)).map(o => o.label)
        return chosen.length === 0 ? (multiple ? "Nenhum" : "—") : chosen.join(", ")
    }

    Rectangle {
        Layout.preferredWidth: 220
        implicitHeight: 28
        radius: Theme.radius
        color: mouse.containsMouse ? Theme.bg2 : Theme.bg1

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.summary
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.expanded ? "󰅃" : "󰅀"
            color: Theme.fg4
            font.family: Theme.font
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
        Layout.preferredWidth: 220
        Layout.preferredHeight: Math.min(count, root.rows) * 28 - (count > 0 ? 2 : 0)
        visible: count > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.expanded ? root.options : []
        onCountChanged: {
            if (count > 0) {
                const i = root.options.findIndex(o => root.has(o.value))
                if (i >= 0)
                    positionViewAtIndex(i, ListView.Center)
            }
        }

        delegate: Rectangle {
            required property var modelData
            width: list.width
            height: 26
            radius: Theme.radius
            color: itemMouse.containsMouse ? Theme.veil : Theme.clear

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.has(modelData.value) ? "󰄬" : "  "}  ${modelData.label}`
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Closing empties the list, and this item goes with it:
                    // pick first, close last
                    if (!root.multiple) {
                        const dropdown = root
                        dropdown.picked(modelData.value)
                        dropdown.expanded = false
                        return
                    }
                    const list = Array.isArray(root.value) ? root.value.slice() : []
                    const i = list.indexOf(modelData.value)
                    if (i >= 0)
                        list.splice(i, 1)
                    else
                        list.push(modelData.value)
                    root.picked(list)
                }
            }
        }
    }
}
