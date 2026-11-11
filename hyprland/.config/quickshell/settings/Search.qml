import QtQuick
import QtQuick.Layouts
import qs.theme
import "ui"
import "schema.js" as Schema
import "searchindex.js" as SearchIndex

// The search at the top of the list: label, description and synonyms of
// every option (searchindex.js); a result opens its page on its card.
// Results come in with a fade and a short slide, leave with a fade, the
// others move to their places and the list grows and shrinks smoothly
// (Theme tokens; reduce motion: fades only)
ColumnLayout {
    id: root

    signal chosen(string page, string card)
    readonly property var entries: SearchIndex.build({ KEYS: Schema.KEYS, PAGES: Schema.PAGES, CARDS: Schema.CARDS })
    property string text: ""
    readonly property var results: SearchIndex.query(entries, text, 8)
    property alias field: field

    spacing: 4

    Field {
        id: field
        Layout.fillWidth: true
        placeholder: "󰍉  Buscar"
        // Results as you type; Enter opens the first
        input.onTextChanged: root.text = input.text
        onAccepted: {
            if (root.results.length > 0)
                root.pick(root.results[0])
        }
    }

    function pick(r) {
        field.input.text = ""
        field.input.focus = false
        root.chosen(r.page, r.card)
    }

    // The results shown, kept in step with `results` one by one (a new
    // list each time would rebuild them all, with no way to animate)
    ListModel {
        id: shown
    }
    onResultsChanged: sync()
    function sync() {
        const keys = results.map(r => `${r.page}/${r.card}/${r.key}/${r.label}`)
        for (let i = shown.count - 1; i >= 0; i--) {
            if (!keys.includes(shown.get(i).uid))
                shown.remove(i)
        }
        for (let i = 0; i < results.length; i++) {
            let j = -1
            for (let k = i; k < shown.count; k++) {
                if (shown.get(k).uid === keys[i]) {
                    j = k
                    break
                }
            }
            const r = results[i]
            if (j < 0)
                shown.insert(i, { uid: keys[i], page: r.page, card: r.card, key: r.key, label: r.label })
            else if (j !== i)
                shown.move(j, i, 1)
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight
        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }
        interactive: false
        model: shown

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(Theme.animNormal) }
            NumberAnimation {
                property: "x"; from: Theme.reduceMotion ? 0 : -Theme.cascadeShift / 3; to: 0
                duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(Theme.animFast) }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.reduceMotion ? 0 : Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
            // An item caught mid-entry still ends fully shown
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.dur(Theme.animFast) }
        }

        delegate: Rectangle {
            id: result
            required property string page
            required property string card
            required property string label
            width: list.width
            implicitHeight: 34
            height: implicitHeight
            radius: Theme.radius
            color: mouse.containsMouse ? Theme.veil : Theme.alpha(Theme.fg, 0)
            Behavior on color {
                ColorAnimation { duration: Theme.dur(Theme.animFast) }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: result.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                Text {
                    Layout.fillWidth: true
                    text: (Schema.PAGES.find(p => p.id === result.page) || {}).name || ""
                    elide: Text.ElideRight
                    color: Theme.gray
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 3
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick({ page: result.page, card: result.card })
            }
        }
    }
}
