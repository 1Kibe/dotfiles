import QtQuick
import qs.theme
import "ui"
import "schema.js" as Schema
import "cascade.js" as Cascade

// The rail on the left of the settings: one icon per page (Schema.PAGES), in
// their order, a thin line between the groups (Aparência, Shell, Sistema).
// The current page has a rounded light behind its icon, the icon in the
// accent's light tone, and a 3 px line in the accent on the rail's left
// edge that slides to the new page (Theme.animNormal). Hover shows the
// page's name beside the icon after a short wait; with the keyboard focus,
// up and down move to the page above or below. Its icons come in one after
// another when the panel opens and leave from the bottom up when it closes.
// Reduce motion: the line jumps, the rest fades.
Item {
    id: root

    property string page: "tema"
    signal picked(string page)

    implicitWidth: 56
    activeFocusOnTab: true

    // Pages and the lines between groups, top to bottom
    readonly property var rows: {
        const out = []
        let group = ""
        for (const p of Schema.PAGES) {
            if (group !== "" && p.group !== group)
                out.push({ divider: true })
            group = p.group
            out.push({ divider: false, page: p })
        }
        return out
    }
    readonly property int pageIndex: Schema.PAGES.findIndex(p => p.id === page)

    // The page above (-1) or below (+1)
    function step(d) {
        const i = pageIndex + d
        if (i >= 0 && i < Schema.PAGES.length)
            picked(Schema.PAGES[i].id)
    }
    Keys.onUpPressed: step(-1)
    Keys.onDownPressed: step(1)
    Keys.onReturnPressed: picked(page)

    function items() {
        const out = []
        for (let i = 0; i < repeater.count; i++)
            out.push(repeater.itemAt(i))
        return out
    }
    function playIn() {
        items().forEach((it, i) => it.motion.playIn(Cascade.inDelay(i, { start: Theme.cascadeStart, stagger: Theme.cascadeStagger / 2 })))
    }
    function playOut() {
        const all = items()
        all.forEach((it, i) => it.motion.playOut(Cascade.outDelay(i, all.length, { outStagger: Theme.cascadeOutStagger / 2 })))
    }
    function hideAll() {
        items().forEach(it => it.motion.hidden())
    }

    // The current page's item (for the line)
    readonly property Item chosenItem: {
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i)
            if (it && !it.modelData.divider && it.modelData.page.id === page)
                return it
        }
        return null
    }

    Column {
        id: column
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            id: repeater
            model: root.rows

            Item {
                id: entry
                required property var modelData
                readonly property bool chosen: !modelData.divider && modelData.page.id === root.page
                width: 40
                height: modelData.divider ? 13 : 40

                transform: Translate { id: shift }
                readonly property alias motion: motion
                CascadeMotion {
                    id: motion
                    target: entry
                    translate: shift
                }

                // Between groups
                Rectangle {
                    visible: entry.modelData.divider
                    anchors.centerIn: parent
                    width: 20
                    height: 1
                    color: Theme.bg2
                }

                Rectangle {
                    visible: !entry.modelData.divider
                    anchors.fill: parent
                    radius: Theme.radius
                    color: entry.chosen ? Theme.bg1 : mouse.containsMouse ? Theme.veil : Theme.alpha(Theme.bg1, 0)
                    Behavior on color {
                        ColorAnimation { duration: Theme.dur(Theme.animFast) }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: entry.modelData.divider ? "" : entry.modelData.page.icon
                        color: entry.chosen ? Theme.accentLight : Theme.fg4
                        Behavior on color {
                            ColorAnimation { duration: Theme.dur(Theme.animFast) }
                        }
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 4
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.forceActiveFocus()
                            root.picked(entry.modelData.page.id)
                        }
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                tip.target = entry
                                tipTimer.restart()
                            } else if (tip.target === entry) {
                                tipTimer.stop()
                                tip.target = null
                            }
                        }
                    }
                }
            }
        }
    }

    // The current page's line on the rail's edge
    Rectangle {
        id: line
        x: 0
        width: 3
        height: 22
        radius: 1.5
        color: Theme.accent
        visible: root.chosenItem !== null
        y: root.chosenItem ? column.y + root.chosenItem.y + (root.chosenItem.height - height) / 2 : 0
        Behavior on y {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }
    }

    // The page's name beside the icon under the mouse, after a short wait
    Timer {
        id: tipTimer
        interval: 150
        onTriggered: tip.shown = tip.target !== null
    }
    Rectangle {
        id: tip
        property Item target: null
        property bool shown: false
        onTargetChanged: if (target === null) shown = false
        readonly property string name: target && !target.modelData.divider ? target.modelData.page.name : ""
        x: root.width + 4
        y: target ? column.y + target.y + (target.height - height) / 2 : 0
        z: 10
        width: tipText.implicitWidth + 16
        height: tipText.implicitHeight + 10
        radius: Math.max(0, Theme.radius - 2)
        color: Theme.bg1
        border.width: 1
        border.color: Theme.bg2
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(Theme.animFast) }
        }
        Text {
            id: tipText
            anchors.centerIn: parent
            text: tip.name
            color: Theme.text
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
    }
}
