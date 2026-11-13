import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "ui"
import "schema.js" as Schema
import "cascade.js" as Cascade

// One page of the settings, drawn from settings/schema.js: each card is a
// group (ui/Group: its title above, the rows in one block), each key a row
// (KeyRow) with the control of its type (KeyControl: bool → switch; a few options
// → segmented, more → list; `control: "swatches"` → color dots; number →
// slider with its unit; text and path → field, monospaced for paths and
// name patterns; list → checked list; a list of this machine (`source`:
// fonts, cursor themes) → a list of those). Two keys that name each other
// (`pair`) share one row, a control each, under the card's `columns`. A
// special card (`component`) is drawn by its file in settings/cards/ inside
// its group (`flush`: no inner margin; a card saying `empty` hides its
// group); `strip`: the card is a strip at the top of the page, with no
// title or block. Every change goes to SettingsStore; a value it
// refuses snaps back by binding. A page with nothing says so.
Flickable {
    id: root

    property string page: "tema"
    readonly property var info: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]

    function keysOf(cardId) {
        // `hidden` keys are kept by the shell itself: never a row
        return Object.keys(Schema.KEYS).filter(k => Schema.KEYS[k].page === page && Schema.KEYS[k].card === cardId
                                                    && Schema.KEYS[k].hidden !== true)
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
                                       "LockSecurity", "ClipboardClear", "EnergyNotices", "BatteryLimit",
                                       "MonitorNotice", "MonitorLayout", "KeyboardLayout", "KeybindList"]
    // A card that needs something this machine does not have stays out
    // (the touchpad's: SystemLists.hasTouchpad). Hyprland tells nothing when
    // a device is plugged in: the devices are read again when this page opens
    onPageChanged: if (page === "teclado") SystemLists.refreshDevices()
    Component.onCompleted: if (page === "teclado") SystemLists.refreshDevices()
    function present(c) {
        return c.needs === undefined || (c.needs === "touchpad" && SystemLists.hasTouchpad)
    }
    readonly property var cards: (Schema.CARDS[page] || []).filter(c => present(c)
                                                                    && (c.component ? builtCards.includes(c.component)
                                                                                    : keysOf(c.id).length > 0))

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
                // A special card with nothing to show here hides its group;
                // one with headerActions puts them at the right of the title
                visible: !(special.item && special.item.empty === true)
                titleActions: special.item && special.item.headerActions ? special.item.headerActions : null
                keys: root.keysOf(cardId)
                columns: modelData.columns || []

                // A special card: its own file (the name comes from the schema)
                Loader {
                    id: special
                    active: group.modelData.component !== undefined
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: group.plain || group.modelData.flush === true ? 0 : 12
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
}
