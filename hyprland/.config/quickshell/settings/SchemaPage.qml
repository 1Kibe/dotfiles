import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "ui"
import "schema.js" as Schema
import "cascade.js" as Cascade
import "format.js" as Format

// One page of the settings, drawn from settings/schema.js: each card is a
// group (ui/Group: its title above, the rows in one block), each key a row
// (ui/OptionRow) with the control of its type (bool → switch; a few options
// → segmented, more → list; `control: "swatches"` → color dots; number →
// slider with its unit; text and path → field, monospaced for paths and
// name patterns; list → checked list; a list of this machine (`source`:
// fonts, cursor themes) → a list of those). Two keys that name each other
// (`pair`) share one row, a control each, under the card's `columns`. A
// special card (`component`) is drawn by its file in settings/cards/ inside
// its group; `strip`: the card is a preview strip at the top of the page,
// with no title or block. Every change goes to SettingsStore; a value it
// refuses snaps back by binding. A page with nothing says so.
Flickable {
    id: root

    property string page: "tema"
    readonly property var info: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]

    function keysOf(cardId) {
        return Object.keys(Schema.KEYS).filter(k => Schema.KEYS[k].page === page && Schema.KEYS[k].card === cardId)
    }
    // The rows of a card: one per key, a pair in the row of its first key
    // (a broken pair, schema.pairProblems, stays as two rows)
    readonly property var brokenPairs: Schema.pairProblems(Schema.KEYS).map(p => p.split(":")[0])
    function rowsOf(cardId) {
        const keys = keysOf(cardId)
        const out = []
        const taken = {}
        for (const k of keys) {
            if (taken[k])
                continue
            const p = Schema.KEYS[k].pair
            if (p !== undefined && keys.includes(p) && !brokenPairs.includes(k) && !brokenPairs.includes(p)) {
                taken[p] = true
                out.push([k, p])
            } else {
                out.push([k])
            }
        }
        return out
    }
    // The special cards built so far (settings/cards/); the others come with
    // the task of their page and stay out until then
    readonly property var builtCards: ["ThemePreview", "WallpaperGallery", "AnimationPreview", "BarItems", "UserPhoto",
                                       "LockSecurity", "ClipboardClear"]
    readonly property var cards: (Schema.CARDS[page] || []).filter(c => c.component ? builtCards.includes(c.component)
                                                                                    : keysOf(c.id).length > 0)

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

    // A page change: the page going out fades (Theme.animFast), then `done`
    // switches the page and starts the new cascade; the opacity comes back
    // in the same step, with the new cards already hidden, so no frame shows
    // both pages or a half-built one
    property var afterLeave: null
    function leave(done) {
        afterLeave = done
        fadeOut.restart()
    }
    NumberAnimation {
        id: fadeOut
        target: column
        property: "opacity"
        to: 0
        duration: Theme.dur(Theme.animFast)
        easing.type: Easing.InCubic
        onFinished: {
            const done = root.afterLeave
            root.afterLeave = null
            if (done)
                done()
            column.opacity = 1
        }
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
        y: 4
        width: root.width - 40
        spacing: 16

        Repeater {
            id: repeater
            model: root.cards

            Group {
                id: group
                required property var modelData
                readonly property string cardId: modelData.id
                Layout.fillWidth: true
                title: modelData.title
                plain: modelData.strip === true
                keys: root.keysOf(cardId)
                columns: modelData.columns || []

                // A special card: its own file (the name comes from the schema)
                Loader {
                    active: group.modelData.component !== undefined
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: group.plain ? 0 : 12
                    source: active ? Qt.resolvedUrl(`cards/${group.modelData.component}.qml`) : ""
                }
                Repeater {
                    model: group.modelData.component ? [] : root.rowsOf(group.cardId)
                    KeyRow {
                        required property var modelData
                        required property int index
                        keys: modelData
                        divider: index > 0
                    }
                }
            }
        }

        // Atalhos and Sobre: their cards come with the next tasks
        Group {
            id: empty
            visible: root.cards.length === 0
            Layout.fillWidth: true
            title: root.info.name
            OptionRow {
                label: "Chega na próxima etapa"
            }
        }
    }

    // One row: one key, or a pair (a control each, under the group's columns)
    component KeyRow: OptionRow {
        id: row

        property var keys: []
        readonly property var spec: Schema.KEYS[keys[0]]
        function valueOf(k) {
            return SettingsStore.ready ? SettingsStore.values[k] : Schema.KEYS[k].def
        }
        readonly property var value: valueOf(keys[0])
        readonly property var changedKeys: keys.filter(k => JSON.stringify(valueOf(k)) !== JSON.stringify(Schema.KEYS[k].def))

        label: spec.label
        changed: changedKeys.length > 0
        defaultText: keys.map(k => Format.value(Schema.KEYS[k], Schema.KEYS[k].def)).join(" / ")
        // A file name pattern shows the name it gives now
        desc: spec.preview === "fileName" && typeof value === "string" && value !== ""
              ? `Fica assim: ${Qt.formatDateTime(new Date(), value)}.png` : (spec.desc || "")

        RowLayout {
            spacing: 12
            Repeater {
                model: row.keys
                // A pair: each control centered in its column's width
                Item {
                    required property string modelData
                    Layout.preferredWidth: row.keys.length > 1 ? 150 : control.implicitWidth
                    implicitHeight: control.implicitHeight
                    KeyControl {
                        id: control
                        key: parent.modelData
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: row.keys.length > 1 ? parent.horizontalCenter : undefined
                        width: Math.min(implicitWidth, parent.width)
                    }
                }
            }
        }
    }

    // The control of one key
    component KeyControl: Loader {
        id: ctl

        property string key
        readonly property var spec: Schema.KEYS[key]
        readonly property var value: SettingsStore.ready ? SettingsStore.values[key] : spec.def

        // A list of this machine: its names, the stored one first if it is
        // not there (the list not read yet, or a font that is gone)
        readonly property var choices: {
            if (!spec.source)
                return spec.options
            // A name never empty ("" is the emptyLabel's choice)
            const names = SystemLists.list(spec.source).filter(n => n !== "")
            const out = names.map(n => ({ value: n, label: n }))
            if (typeof value === "string" && !names.includes(value) && !(value === "" && spec.emptyLabel))
                out.unshift({ value: value, label: value })
            // "" as a choice of its own (the wallpaper on every screen)
            if (spec.emptyLabel)
                out.unshift({ value: "", label: spec.emptyLabel })
            return out
        }

        sourceComponent: spec.source ? dropdownC
                         : spec.control === "swatches" ? swatchesC
                         : spec.type === "bool" ? toggleC
                         : spec.type === "enum" ? (spec.options.length <= 4 ? segmentedC : dropdownC)
                         : spec.type === "int" || spec.type === "real" ? sliderC
                         : spec.type === "list" ? listC
                         : fieldC

        Component {
            id: toggleC
            Toggle {
                checked: ctl.value === true
                onToggled: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: swatchesC
            ColorSwatches {
                options: ctl.spec.options
                value: ctl.value
                onPicked: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: segmentedC
            Segmented {
                options: ctl.spec.options
                value: ctl.value
                onPicked: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: dropdownC
            Dropdown {
                options: ctl.choices
                value: ctl.value
                onPicked: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: listC
            Dropdown {
                multiple: true
                options: ctl.spec.options
                value: ctl.value
                onPicked: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: sliderC
            Slider {
                from: ctl.spec.min
                to: ctl.spec.max
                step: ctl.spec.step || 1
                value: ctl.value
                valueText: Format.value(ctl.spec, ctl.value)
                onMoved: v => SettingsStore.set(ctl.key, v)
            }
        }
        Component {
            id: fieldC
            Field {
                value: String(ctl.value)
                mono: ctl.spec.type === "path" || ctl.spec.preview === "fileName"
                onAccepted: text => invalid = !SettingsStore.set(ctl.key, text)
            }
        }
    }
}
