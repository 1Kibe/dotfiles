import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "ui"
import "schema.js" as Schema
import "cascade.js" as Cascade

// One page of the settings, drawn from settings/schema.js: its cards, and in
// each a row per key with the control of its type (bool → switch; a few
// options → segmented, more → list; number → slider; text and path → field;
// list → checked list). Every change goes to SettingsStore; a value it
// refuses snaps back by binding. Special cards (a `component`) come with the
// task of their page; a page with nothing else says so.
Flickable {
    id: root

    property string page: "tema"
    readonly property var info: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]

    function keysOf(cardId) {
        return Object.keys(Schema.KEYS).filter(k => Schema.KEYS[k].page === page && Schema.KEYS[k].card === cardId)
    }
    readonly property var cards: (Schema.CARDS[page] || []).filter(c => !c.component && keysOf(c.id).length > 0)

    contentWidth: width
    contentHeight: column.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // The cascade of the cards, from `start` ms (the panel opening: after the
    // list's start; a page change: at once)
    function cardItems() {
        const out = []
        for (let i = 0; i < repeater.count; i++)
            out.push(repeater.itemAt(i))
        if (empty.visible)
            out.push(empty)
        return out
    }
    function playIn(start) {
        contentY = 0
        const items = cardItems()
        items.forEach((c, i) => c.motion.playIn(Cascade.inDelay(i, { start: start, stagger: Theme.cascadeStagger })))
    }
    function playOut() {
        const items = cardItems()
        items.forEach((c, i) => c.motion.playOut(Cascade.outDelay(i, items.length, { outStagger: Theme.cascadeOutStagger })))
    }
    function hideAll() {
        cardItems().forEach(c => c.motion.hidden())
    }

    // A search result: scroll to its card and light it up
    function showCard(cardId) {
        for (let i = 0; i < repeater.count; i++) {
            const c = repeater.itemAt(i)
            if (c.cardId === cardId) {
                contentY = Math.max(0, Math.min(c.y, contentHeight - height))
                c.flash()
                return
            }
        }
    }

    ColumnLayout {
        id: column
        x: 20
        y: 20
        width: root.width - 40
        spacing: 12

        Text {
            text: root.info.name
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize + 5
            font.bold: true
        }
        Text {
            Layout.bottomMargin: 4
            text: root.info.sub
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }

        Repeater {
            id: repeater
            model: root.cards

            Card {
                id: card
                required property var modelData
                readonly property string cardId: modelData.id
                Layout.fillWidth: true
                title: modelData.title

                Repeater {
                    model: root.keysOf(card.cardId)
                    KeyRow {
                        required property string modelData
                        key: modelData
                    }
                }
            }
        }

        // Atalhos and Sobre: their cards come with the next tasks
        Card {
            id: empty
            visible: root.cards.length === 0
            Layout.fillWidth: true
            title: root.info.name
            Text {
                text: "Chega na próxima etapa"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
        }
    }

    component KeyRow: OptionRow {
        id: row

        required property string key
        readonly property var spec: Schema.KEYS[key]
        // The default until the store has read the files
        readonly property var value: SettingsStore.ready ? SettingsStore.values[key] : spec.def

        label: spec.label
        desc: spec.desc || ""

        Loader {
            sourceComponent: row.spec.type === "bool" ? toggleC
                             : row.spec.type === "enum" ? (row.spec.options.length <= 4 ? segmentedC : dropdownC)
                             : row.spec.type === "int" || row.spec.type === "real" ? sliderC
                             : row.spec.type === "list" ? listC
                             : fieldC
        }

        Component {
            id: toggleC
            Toggle {
                checked: row.value === true
                onToggled: v => SettingsStore.set(row.key, v)
            }
        }
        Component {
            id: segmentedC
            Segmented {
                options: row.spec.options
                value: row.value
                onPicked: v => SettingsStore.set(row.key, v)
            }
        }
        Component {
            id: dropdownC
            Dropdown {
                options: row.spec.options
                value: row.value
                onPicked: v => SettingsStore.set(row.key, v)
            }
        }
        Component {
            id: listC
            Dropdown {
                multiple: true
                options: row.spec.options
                value: row.value
                onPicked: v => SettingsStore.set(row.key, v)
            }
        }
        Component {
            id: sliderC
            Slider {
                from: row.spec.min
                to: row.spec.max
                step: row.spec.step || 1
                value: row.value
                onMoved: v => SettingsStore.set(row.key, v)
            }
        }
        Component {
            id: fieldC
            Field {
                value: String(row.value)
                onAccepted: text => invalid = !SettingsStore.set(row.key, text)
            }
        }
    }
}
