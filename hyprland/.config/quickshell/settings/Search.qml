import QtQuick
import QtQuick.Layouts
import qs.theme
import "ui"
import "schema.js" as Schema
import "searchindex.js" as SearchIndex

// The search at the top of the list: label, description and synonyms of
// every option (searchindex.js); a result opens its page on its card
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

    Repeater {
        model: root.results

        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Theme.radius
            color: mouse.containsMouse ? Theme.veil : Theme.clear

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                Text {
                    Layout.fillWidth: true
                    text: (Schema.PAGES.find(p => p.id === modelData.page) || {}).name || ""
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
                onClicked: root.pick(modelData)
            }
        }
    }
}
