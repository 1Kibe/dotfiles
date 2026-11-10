import QtQuick
import QtQuick.Layouts
import qs.theme
import "ui"
import "schema.js" as Schema
import "cascade.js" as Cascade

// The list on the left of the settings: the search, then the pages in their
// groups (Aparência, Shell, Sistema), each with its icon and a short line.
// Its rows come in one after another when the panel opens and leave from
// the bottom up when it closes.
Item {
    id: root

    property string page: "tema"
    signal picked(string page)
    signal searched(string page, string card)
    property alias search: search

    // Group titles and pages, top to bottom
    readonly property var rows: {
        const out = []
        let group = ""
        for (const p of Schema.PAGES) {
            if (p.group !== group) {
                group = p.group
                out.push({ header: true, text: group })
            }
            out.push({ header: false, page: p })
        }
        return out
    }

    function items() {
        const out = [search]
        for (let i = 0; i < repeater.count; i++)
            out.push(repeater.itemAt(i))
        return out
    }
    function playIn() {
        items().forEach((it, i) => it.motion.playIn(Cascade.inDelay(i, { start: Theme.cascadeStart, stagger: Theme.cascadeStagger })))
    }
    function playOut() {
        const all = items()
        all.forEach((it, i) => it.motion.playOut(Cascade.outDelay(i, all.length, { outStagger: Theme.cascadeOutStagger })))
    }
    function hideAll() {
        items().forEach(it => it.motion.hidden())
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 2

        Search {
            id: search
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            onChosen: (page, card) => root.searched(page, card)
            transform: Translate { id: searchShift }
            readonly property alias motion: searchMotion
            CascadeMotion {
                id: searchMotion
                target: search
                translate: searchShift
            }
        }

        Repeater {
            id: repeater
            model: root.rows

            Rectangle {
                id: entry
                required property var modelData
                readonly property bool chosen: !modelData.header && modelData.page.id === root.page
                Layout.fillWidth: true
                Layout.topMargin: modelData.header ? 10 : 0
                implicitHeight: modelData.header ? 22 : 44
                radius: Theme.radius
                color: chosen ? Theme.bg1 : !modelData.header && mouse.containsMouse ? Theme.veil : Theme.clear

                transform: Translate { id: shift }
                readonly property alias motion: motion
                CascadeMotion {
                    id: motion
                    target: entry
                    translate: shift
                }

                // Group title
                Text {
                    visible: entry.modelData.header
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    text: entry.modelData.header ? entry.modelData.text : ""
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 2
                    font.bold: true
                }

                // A page: icon, name and its short line
                RowLayout {
                    visible: !entry.modelData.header
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    // Fixed width: the glyphs differ, the names stay lined up
                    Text {
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: entry.modelData.header ? "" : entry.modelData.page.icon
                        color: entry.chosen ? Theme.accentLight : Theme.fg4
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 3
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.header ? "" : entry.modelData.page.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.header ? "" : entry.modelData.page.sub
                            elide: Text.ElideRight
                            color: Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 3
                        }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: !entry.modelData.header
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(entry.modelData.page.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
