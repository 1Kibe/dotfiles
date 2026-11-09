import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// The strip at the bottom of the clipboard overlay: tabs, kind filters,
// search and "Limpar" on top; pinned and recent cards in one row that
// scrolls sideways; keyboard hints at the bottom. The Emoji tab swaps the
// filters for emoji groups and the cards for an emoji grid. Keys: arrows
// move, Enter copies, Ctrl+P pins, Del deletes, Tab switches tab, Esc
// clears the search or closes; anything else types into the search.
Rectangle {
    id: root

    property string tab: "history"       // "history" or "emoji"
    property string kind: "all"         // filter chip
    property string emojiCat: "faces"   // emoji group chip
    // Filters the cards (matches) and the emoji (EmojiStore.list)
    property string query: search.text
    // "Limpar" waiting for its second click; reset on each opening
    property bool clearArmed: false
    property int selected: 0             // index among the cards (headers skipped)

    readonly property var chips: [
        { key: "all", label: "Tudo" },
        { key: "text", label: "Texto" },
        { key: "image", label: "Imagem" },
        { key: "link", label: "Link" },
        { key: "code", label: "Código" },
        { key: "color", label: "Cor" }
    ]

    function matches(entry) {
        if (kind !== "all" && entry.kind !== kind)
            return false
        if (query === "")
            return true
        const q = query.toLowerCase()
        // Images have no text: they match "imagem" or their format (png, jpeg)
        if (entry.kind === "image")
            return "imagem".includes(q) || entry.mime.toLowerCase().includes(q)
        return entry.text.toLowerCase().includes(q)
    }

    // Pinned first, then recents (an entry already pinned is not repeated);
    // a narrow header before each group
    readonly property var cards: {
        const pinned = ClipboardStore.pins.filter(matches)
        // Texts are compared by content; images are always listed
        const pinnedTexts = new Set(ClipboardStore.pins.filter(p => p.kind !== "image").map(p => p.text))
        const recent = ClipboardStore.items.filter(i => matches(i) && !(i.kind !== "image" && pinnedTexts.has(i.text)))
        return pinned.concat(recent)
    }
    readonly property int pinnedCount: ClipboardStore.pins.filter(matches).length
    // ListView rows: { header } or { card, index }; index is the place in
    // cards, which is what selected counts
    readonly property var model: {
        const out = []
        if (pinnedCount > 0)
            out.push({ header: "Fixados" })
        cards.forEach((c, i) => {
            // Before the first recent card (also when nothing is pinned)
            if (i === pinnedCount && cards.length > pinnedCount)
                out.push({ header: "Recentes" })
            out.push({ card: c, index: i })
        })
        return out
    }

    // A delete or a new filter keeps the selection inside the list
    onCardsChanged: selected = Math.max(0, Math.min(selected, cards.length - 1))
    onKindChanged: selected = 0
    onQueryChanged: selected = 0
    onSelectedChanged: {
        const row = model.findIndex(m => m.card !== undefined && m.index === selected)
        // Row 1 is the first card after a header: go to the very start so
        // the header shows too
        if (row >= 0)
            row === 1 ? strip.positionViewAtBeginning() : strip.positionViewAtIndex(row, ListView.Contain)
    }

    // Called by ClipboardOverlay on each opening
    function reset() {
        search.text = ""
        tab = "history"
        kind = "all"
        selected = 0
        clearArmed = false
        strip.positionViewAtBeginning()
        search.forceActiveFocus()
    }

    // Emoji tab opens on the recent ones when there are any
    function showEmoji() {
        EmojiStore.ensureLoaded()
        emojiCat = EmojiStore.recent.length > 0 ? "recent" : "faces"
        tab = "emoji"
    }

    // Called by ClipboardOverlay when a note gives up the keyboard
    function focusSearch() {
        search.forceActiveFocus()
    }

    // The card that Enter, Ctrl+P and Del act on
    function current() {
        return cards.length > 0 ? cards[selected] : null
    }

    implicitHeight: Theme.stripHeight
    radius: Theme.stripRadius
    color: Theme.stripFill

    // Clicks on the strip never reach the dark area behind it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        // A vertical wheel scrolls the row sideways (x8 for a useful speed)
        onWheel: event => strip.flick(event.angleDelta.y * 8, 0)
    }

    component Chip: Rectangle {
        id: chip

        required property string label
        property bool active: false
        property bool enabled: true
        signal pressed()

        // 10 px each side of the label; a radius of half the height makes a pill
        implicitWidth: chipText.implicitWidth + 20
        implicitHeight: 26
        radius: height / 2
        color: active ? Theme.alpha(Theme.accentLight, 0.22) : chipMouse.containsMouse && enabled ? Theme.veil : Theme.clear
        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: !chip.enabled ? Theme.bg2 : chip.active ? Theme.text : Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.pressed()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Tabs, filters, search, clear
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Chip {
                label: "Histórico"
                active: root.tab === "history"
                onPressed: {
                    root.tab = "history"
                    search.forceActiveFocus()
                }
            }
            Chip {
                label: "Emoji"
                active: root.tab === "emoji"
                onPressed: {
                    root.showEmoji()
                    search.forceActiveFocus()
                }
            }
            Rectangle {
                implicitWidth: 1
                implicitHeight: 18
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Theme.bg2
            }
            Repeater {
                // Kind filters on the history tab, emoji groups on the Emoji tab
                model: root.tab === "history" ? root.chips : EmojiStore.categories

                Chip {
                    required property var modelData
                    label: modelData.label
                    // While searching emoji, the search covers every group
                    active: root.tab === "history" ? root.kind === modelData.key
                                                   : root.query === "" && root.emojiCat === modelData.key
                    onPressed: {
                        if (root.tab === "history") {
                            root.kind = modelData.key
                        } else {
                            root.emojiCat = modelData.key
                            // Otherwise the search would still cover every group
                            search.text = ""
                        }
                        search.forceActiveFocus()
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }

            // Search: always has the keyboard while the overlay is open
            Rectangle {
                implicitWidth: 240
                implicitHeight: 28
                radius: height / 2
                color: Theme.alpha(Theme.bg1, 0.7)

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    color: Theme.gray
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                }
                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accentLight, 0.4)
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                    focus: true

                    Text {
                        visible: search.text === ""
                        text: "Buscar"
                        color: Theme.gray
                        font: search.font
                    }

                    // Every key lands here: navigation keys are handled and
                    // accepted, any other key types into the field
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            if (root.tab === "history")
                                root.showEmoji()
                            else
                                root.tab = "history"
                        } else if (event.key === Qt.Key_Escape) {
                            // First Esc clears the search, the next one closes
                            if (search.text !== "")
                                search.text = ""
                            else
                                ClipboardStore.close()
                        } else if (root.tab === "emoji") {
                            // Arrows and Enter go to the emoji grid; other keys type
                            if (!emojiGrid.key(event))
                                return
                        } else if (event.key === Qt.Key_Left) {
                            root.selected = Math.max(0, root.selected - 1)
                        } else if (event.key === Qt.Key_Right) {
                            root.selected = Math.min(root.cards.length - 1, root.selected + 1)
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.current())
                                ClipboardStore.copy(root.current())
                        } else if (ctrl && event.key === Qt.Key_P) {
                            if (root.current())
                                ClipboardStore.togglePin(root.current())
                        } else if (event.key === Qt.Key_Delete) {
                            if (root.current())
                                ClipboardStore.remove(root.current())
                        } else {
                            return
                        }
                        // Only reached by a handled key (the others returned above)
                        event.accepted = true
                    }
                }
            }

            // Clear the history (pins stay); second click confirms
            Rectangle {
                visible: root.tab === "history"
                implicitWidth: clearText.implicitWidth + 24
                implicitHeight: 28
                radius: height / 2
                color: root.clearArmed ? Theme.danger : clearMouse.containsMouse ? Theme.veil : Theme.clear
                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: root.clearArmed ? "Clique de novo para limpar" : "Limpar"
                    color: root.clearArmed ? Theme.red : Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.clearArmed) {
                            root.clearArmed = false
                            ClipboardStore.wipe()
                        } else {
                            root.clearArmed = true
                        }
                        // A click takes the focus from the search: give it back
                        search.forceActiveFocus()
                    }
                }
            }
        }

        // The cards
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.cardSize

            EmojiGrid {
                id: emojiGrid
                anchors.fill: parent
                visible: root.tab === "emoji"
                // Filtered only on the Emoji tab, so typing in the history
                // never walks the whole emoji list
                model: root.tab === "emoji" ? EmojiStore.list(root.emojiCat, root.query) : []
                emptyText: root.query === "" && root.emojiCat === "recent" ? "Nenhum emoji usado ainda" : "Nada encontrado"
            }

            ListView {
                id: strip
                anchors.fill: parent
                visible: root.tab === "history"
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Two cards past each edge stay created (with their previews)
                cacheBuffer: Theme.cardSize * 2
                model: root.model

                delegate: Item {
                    id: slot

                    required property var modelData
                    readonly property bool isHeader: modelData.header !== undefined

                    // A header is a narrow column with its title rotated
                    width: isHeader ? 22 : Theme.cardSize
                    height: Theme.cardSize

                    // Group title, written upwards
                    Text {
                        visible: slot.isHeader
                        anchors.centerIn: parent
                        rotation: -90
                        text: slot.isHeader ? slot.modelData.header : ""
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }

                    Loader {
                        // A ClipCard needs an entry: none for header rows
                        active: !slot.isHeader
                        anchors.fill: parent
                        sourceComponent: ClipCard {
                            entry: slot.modelData.card
                            selected: slot.modelData.index === root.selected
                            onActivated: ClipboardStore.copy(slot.modelData.card)
                        }
                    }
                }
            }

            Text {
                // Waits for the first load, so "empty" never flashes while cliphist runs
                visible: root.tab === "history" && ClipboardStore.loaded && root.cards.length === 0
                anchors.centerIn: parent
                text: root.query !== "" || root.kind !== "all" ? "Nada encontrado" : "Nada copiado ainda"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Key hints; on the Emoji tab they start with the English name of the
        // selected emoji
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.tab === "history"
                  ? "← → navegar   ·   Enter copiar   ·   Ctrl+P fixar   ·   Del apagar   ·   Tab emoji   ·   digite para buscar   ·   Esc fechar"
                  : `${emojiGrid.current && emojiGrid.current.name ? emojiGrid.current.name + "   ·   " : ""}setas navegar   ·   Enter copiar   ·   Tab histórico   ·   digite para buscar (em inglês)   ·   Esc fechar`
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }
    }
}
