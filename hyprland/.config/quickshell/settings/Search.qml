import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "ui"
import "schema.js" as Schema
import "searchindex.js" as SearchIndex

// The search in the page's header ("Buscar em tudo"): label, description
// and synonyms of every option (searchindex.js); a result opens its page on
// its card. The results open under the field, over the page. They come in
// with a fade and a short slide, leave with a fade, the others move to their
// places and the list grows and shrinks smoothly (Theme tokens; reduce
// motion: fades only)
Item {
    id: root

    signal chosen(string page, string card)
    // A card this machine does not have (the touchpad's) gives no results
    readonly property var allEntries: SearchIndex.build({ KEYS: Schema.KEYS, PAGES: Schema.PAGES, CARDS: Schema.CARDS })
    readonly property var entries: allEntries.filter(e => e.needs === "" || (e.needs === "touchpad" && SystemLists.hasTouchpad))
    property string text: ""
    readonly property var results: SearchIndex.query(entries, text, 8)
    property alias field: field

    implicitWidth: 220
    implicitHeight: field.implicitHeight

    Field {
        id: field
        width: parent.width
        placeholder: "󰍉  Buscar em tudo"
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

    // The results, over the page under the field
    Rectangle {
        id: popup
        y: field.height + 4
        width: Math.max(parent.width, 280)
        x: parent.width - width
        height: list.height + (list.count > 0 ? 8 : 0)
        visible: height > 1
        clip: true
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg1
        Behavior on height {
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }

    ListView {
        id: list
        x: 4
        y: 4
        width: parent.width - 8
        height: contentHeight
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
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
                Text {
                    Layout.fillWidth: true
                    text: (Schema.PAGES.find(p => p.id === result.page) || {}).name || ""
                    elide: Text.ElideRight
                    color: Theme.gray
                    font.family: Theme.fontPanels
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
}
