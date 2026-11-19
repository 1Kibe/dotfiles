import QtQuick
import QtQuick.Layouts
import qs.theme
import "lists.js" as Lists

// One origin of the Atualizações section ("Sistema", pacman; "AUR", paru):
// its header (the name; the tool, the count and the last check's time on
// the right) and its block: the first packages, "name  old → new" (the
// versions in the mono font, the new one green), then "e mais N", which
// opens the rest, scrolling inside the block; with nothing to list, one
// line saying why. Names and versions show as plain text.
ColumnLayout {
    id: root

    required property string title
    required property string toolName
    // Updates.sys or Updates.aur
    required property var info
    // "e mais N" opened
    required property bool all
    // The last check's time ("" none)
    property string time: ""
    property real maxHeight: 220
    // The keyboard is on "e mais N"
    property bool moreFocus: false
    signal opened()

    readonly property string why: Lists.updatesWhy(info)
    readonly property var rows: info.state === "missing" ? [] : all ? info.list : info.list.slice(0, Lists.UPDATES_SHOWN)
    readonly property int more: Lists.updatesHidden(info, all)
    readonly property bool opens: Lists.updatesCanOpen(info, all)

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        title: root.title
        detail: Lists.updatesTool(root.info, root.toolName, root.time)
    }
    ListBlock {
        maxHeight: root.maxHeight

        Repeater {
            model: root.rows

            ListRow {
                required property var modelData
                required property int index
                divider: index > 0
                text: modelData.name
                detail: modelData.from
                detailMono: true
                detailMax: 110

                Text {
                    text: "→"
                    textFormat: Text.PlainText
                    color: Theme.fg4
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSizeSmall
                }
                Text {
                    Layout.maximumWidth: 110
                    text: modelData.to
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    elide: Text.ElideLeft
                    color: Theme.green
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSizeSmall
                }
            }
        }
        // Why there is nothing to list, or that the check failed this time
        ListRow {
            visible: root.why !== ""
            divider: root.rows.length > 0
            text: root.why
            textColor: root.info.state === "failed" ? Theme.red : Theme.gray
        }
        ListRow {
            visible: root.more > 0
            divider: true
            action: true
            clickable: root.opens
            keyFocus: root.moreFocus
            text: `e mais ${root.more}`
            onClicked: root.opened()
        }
    }
}
