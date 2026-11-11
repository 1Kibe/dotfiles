import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../schema.js" as Schema
import "../../bar/baritems.js" as BarItems

// The bar's items (Configurações → Barra): the three areas, each with its
// items in order. Dragging an item drops it before another one, or at the
// end of an area; the eye hides it from the bar without taking it out.
// "Restaurar padrão" puts back the default arrangement. Every change goes to
// the store at once (barLeft, barCenter, barRight, barHidden).
Item {
    id: root

    implicitHeight: column.implicitHeight

    readonly property var areaKeys: [{ key: "barLeft", label: "Esquerda" }, { key: "barCenter", label: "Centro" },
                                     { key: "barRight", label: "Direita" }]
    readonly property var labels: {
        const out = {}
        for (const o of Schema.KEYS.barLeft.options)
            out[o.value] = o.label
        return out
    }
    function list(key) {
        return SettingsStore.ready ? SettingsStore.get(key) : Schema.KEYS[key].def
    }
    readonly property var hidden: SettingsStore.ready ? SettingsStore.get("barHidden") : []

    // ── Drag ──
    property string dragging: ""
    // Where it would land: { area, index } (null: nowhere)
    property var target: null

    function drop() {
        const t = target
        const id = dragging
        dragging = ""
        target = null
        if (!t || id === "")
            return
        const lists = { barLeft: list("barLeft"), barCenter: list("barCenter"), barRight: list("barRight") }
        // The index counts the area without the dragged item
        const before = lists[t.area].indexOf(id)
        const index = before >= 0 && before < t.index ? t.index - 1 : t.index
        const next = BarItems.moveItem(lists, id, t.area, index)
        for (const key of ["barLeft", "barCenter", "barRight"])
            SettingsStore.set(key, next[key])
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: root.areaKeys

            ColumnLayout {
                id: area
                required property var modelData
                readonly property var ids: root.list(modelData.key)
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: area.modelData.label
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }

                // The area itself takes a drop at its end
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(36, flow.implicitHeight + 8)
                    radius: Theme.radius
                    color: areaDrop.containsDrag ? Theme.veil : Theme.bg1
                    Behavior on color {
                        ColorAnimation { duration: Theme.dur(Theme.animFast) }
                    }

                    DropArea {
                        id: areaDrop
                        anchors.fill: parent
                        keys: ["bar-item"]
                        onEntered: root.target = { area: area.modelData.key, index: area.ids.length }
                    }

                    Flow {
                        id: flow
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 4

                        Repeater {
                            model: area.ids

                            Rectangle {
                                id: chip
                                required property string modelData
                                required property int index
                                readonly property bool hiddenHere: root.hidden.includes(modelData)
                                readonly property bool marked: root.target !== null && root.dragging !== ""
                                                               && root.target.area === area.modelData.key
                                                               && root.target.index === index
                                width: chipRow.implicitWidth + 16
                                height: 28
                                radius: Theme.radius
                                color: root.dragging === modelData ? Theme.bg2 : mouse.containsMouse ? Theme.bg2 : Theme.bg
                                opacity: root.dragging === modelData ? 0.4 : hiddenHere ? 0.6 : 1
                                border.width: marked ? 2 : 0
                                border.color: Theme.accentLight
                                Behavior on color {
                                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.dur(Theme.animFast) }
                                }

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰇛"
                                        color: Theme.gray
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSize - 1
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.labels[chip.modelData] || chip.modelData
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSize - 1
                                        font.strikeout: chip.hiddenHere
                                    }
                                    // The eye: hide or show, the item stays in place
                                    Text {
                                        id: eye
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: chip.hiddenHere ? "󰈉" : "󰈈"
                                        color: eyeMouse.containsMouse ? Theme.text : Theme.fg4
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSize
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.dur(Theme.animFast) }
                                        }
                                        MouseArea {
                                            id: eyeMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SettingsStore.set("barHidden", BarItems.toggleHidden(root.hidden, chip.modelData))
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: root.dragging !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                }
                                // Dropping on an item puts the dragged one before it
                                DropArea {
                                    anchors.fill: parent
                                    keys: ["bar-item"]
                                    onEntered: root.target = { area: area.modelData.key, index: chip.index }
                                }
                                DragHandler {
                                    id: handler
                                    target: null
                                    onActiveChanged: {
                                        if (active) {
                                            ghost.text = root.labels[chip.modelData] || chip.modelData
                                            root.dragging = chip.modelData
                                        } else {
                                            root.drop()
                                        }
                                    }
                                    onCentroidChanged: {
                                        if (!active)
                                            return
                                        const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y)
                                        ghost.x = p.x - ghost.width / 2
                                        ghost.y = p.y - ghost.height / 2
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Button {
            text: "Restaurar padrão"
            icon: "󰑓"
            onClicked: {
                for (const key of ["barLeft", "barCenter", "barRight", "barHidden"])
                    SettingsStore.reset(key)
            }
        }
    }

    // What follows the pointer while dragging (the drop areas see it)
    Rectangle {
        id: ghost
        property alias text: ghostText.text
        z: 10
        visible: root.dragging !== ""
        width: ghostText.implicitWidth + 24
        height: 28
        radius: Theme.radius
        color: Theme.accent
        Drag.active: root.dragging !== ""
        Drag.keys: ["bar-item"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Text {
            id: ghostText
            anchors.centerIn: parent
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }
}
