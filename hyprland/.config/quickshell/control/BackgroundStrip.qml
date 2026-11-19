import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// "Em segundo plano", at the end of the control center: one chip per app
// running in the background (TrayApps: the tray items), two lines at most,
// the rest behind "+N", which opens the whole list in its place (the
// "background" section, in the sections' common parts). Nothing shows with
// no app. A click opens the app (activate(); an item that is only a menu
// opens its menu); the right button opens its menu, drawn here (levels
// read only when opened, TRAY_MENU_DEPTH deep, TRAY_MENU_MAX entries, the
// text cleaned; check and radio entries only show their state; the one
// action is the entry's own triggered()). The × is the app's own quit
// entry (TrayApps.quit), never a signal; apps with no single quit entry,
// and the TRAY_NO_QUIT ids, have no ×. A yellow dot: the app asks for
// attention. Names and menu text from outside show as plain text.
ColumnLayout {
    id: root

    // The center open
    required property bool active
    // The most the opened list takes before scrolling inside
    property real listMax: 400
    // The keyboard: on the chips (its own group) or on the opened list
    property int chipKeyIndex: -1
    property int listKeyIndex: -1

    readonly property var items: TrayApps.items
    readonly property bool expanded: active && ShellState.controlSection === "background"
    // The list is made (and the menus' top level read) only while the
    // center is open (TrayApps.watch)
    readonly property bool watching: active
    onWatchingChanged: TrayApps.watch(watching)
    Component.onDestruction: {
        if (watching)
            TrayApps.watch(false)
    }

    visible: items.length > 0
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Layout.topMargin: 6
    spacing: 4

    // An empty list closes its section; a closed center closes the menu
    onItemsChanged: {
        if (items.length === 0 && ShellState.controlSection === "background")
            ShellState.closeControlSection()
        if (menuItem !== null && !items.includes(menuItem))
            closeMenu()
        Qt.callLater(measure)
    }
    onActiveChanged: closeMenu()
    Component.onCompleted: Qt.callLater(measure)
    Connections {
        target: TrayApps
        function onLockedChanged() {
            if (TrayApps.locked)
                root.closeMenu()
        }
    }

    // ── How many chips fit in two lines, the last place for "+N" ──
    property var widths: []
    readonly property int shown: Lists.trayFit(widths, flow.width, flow.spacing, 44, 2)
    function measure() {
        const w = []
        for (let i = 0; i < chips.count; i++) {
            const c = chips.itemAt(i)
            w.push(c ? c.implicitWidth : 0)
        }
        widths = w
    }

    // ── Opening an app, its menu, its quit entry ──
    function open(item) {
        const r = TrayApps.activate(item)
        if (r === "menu")
            openMenu(item)
        else if (r === "done")
            ShellState.close()
    }
    function canQuit(item) {
        return TrayApps.quitEntry(item) !== null
    }
    property var menuItem: null
    property var menuStack: []
    function openMenu(item) {
        if (!active || TrayApps.locked || !item || !item.hasMenu)
            return
        menuItem = item
        menuStack = [item.menu]
    }
    function closeMenu() {
        menuItem = null
        menuStack = []
    }
    function pressEntry(e) {
        if (!e || !e.enabled || e.isSeparator)
            return
        if (e.hasChildren) {
            if (menuStack.length < Lists.TRAY_MENU_DEPTH)
                menuStack = menuStack.concat([e.entry])
            return
        }
        if (TrayApps.trigger(e.entry))
            closeMenu()
    }
    // An entry of the level shown (the keyboard and the tests)
    function menuEntryAt(j) {
        return menuReader.entries[j] ?? null
    }
    function back() {
        if (menuStack.length > 1)
            menuStack = menuStack.slice(0, -1)
    }
    TrayMenu {
        id: menuReader
        menu: root.menuStack.length > 0 ? root.menuStack[root.menuStack.length - 1] : null
    }

    // ── The keyboard ──
    // The menu's items, after the strip's or the list's own
    readonly property var menuKeys: {
        if (menuItem === null)
            return []
        const k = []
        if (menuStack.length > 1)
            k.push({ kind: "back" })
        menuReader.entries.forEach((e, j) => {
            if (e.enabled && !e.isSeparator)
                k.push({ kind: "entry", index: j })
        })
        k.push({ kind: "close" })
        return k
    }
    readonly property var chipKeys: {
        if (expanded)
            return []
        const k = []
        for (let i = 0; i < Math.min(shown, items.length); i++) {
            k.push({ kind: "open", index: i })
            if (canQuit(items[i]))
                k.push({ kind: "quit", index: i })
        }
        if (shown < items.length)
            k.push({ kind: "more" })
        return k.concat(menuKeys)
    }
    readonly property var listKeyItems: {
        if (!expanded)
            return []
        const k = []
        items.forEach((it, i) => {
            k.push({ kind: "open", index: i })
            if (it.hasMenu)
                k.push({ kind: "menu", index: i })
            if (canQuit(it))
                k.push({ kind: "quit", index: i })
        })
        k.push({ kind: "less" })
        return k.concat(menuKeys)
    }
    readonly property int chipKeyCount: chipKeys.length
    function chipKeyOn(kind, i) {
        const it = chipKeys[chipKeyIndex]
        return it !== undefined && it.kind === kind && (i === undefined || it.index === i)
    }
    function listKeyOn(kind, i) {
        const it = listKeyItems[listKeyIndex]
        return it !== undefined && it.kind === kind && (i === undefined || it.index === i)
    }
    function menuKeyOn(kind, j) {
        return (expanded ? listKeyOn(kind, j) : chipKeyOn(kind, j))
    }
    // The item the keyboard went to, kept by itself (the list is sorted by
    // name and can change under the ring): Enter acts on that item, or on
    // nothing if it went away
    property var chipFocus: null
    property var listFocus: null
    function snap(list, k) {
        const it = list[k]
        if (!it)
            return null
        return { kind: it.kind, item: it.index !== undefined && it.kind !== "entry" ? items[it.index] ?? null : null }
    }
    onChipKeyIndexChanged: chipFocus = snap(chipKeys, chipKeyIndex)
    onListKeyIndexChanged: listFocus = snap(listKeyItems, listKeyIndex)
    function press(it, focus) {
        if (!it)
            return
        let item = null
        if (it.index !== undefined && it.kind !== "entry") {
            item = focus && focus.kind === it.kind && focus.item ? focus.item : items[it.index]
            if (!item || !items.includes(item))
                return
        }
        if (it.kind === "open")
            open(item)
        else if (it.kind === "quit")
            TrayApps.quit(item)
        else if (it.kind === "menu")
            openMenu(item)
        else if (it.kind === "more")
            ShellState.setControlSection("background")
        else if (it.kind === "less")
            ShellState.closeControlSection()
        else if (it.kind === "back")
            back()
        else if (it.kind === "entry")
            pressEntry(menuReader.entries[it.index])
        else if (it.kind === "close")
            closeMenu()
    }
    function pressChipKey(k) {
        press(chipKeys[k], chipFocus)
    }
    // The opened list, as the control center's section list
    readonly property QtObject listKeys: QtObject {
        readonly property int keyCount: root.listKeyItems.length
        function pressKey(k) {
            root.press(root.listKeyItems[k], root.listFocus)
        }
    }

    ListHeader {
        Layout.leftMargin: 0
        Layout.rightMargin: 0
        title: "Em segundo plano"
    }

    // ── The chips ──
    Flow {
        id: flow
        visible: !root.expanded
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            id: chips
            model: root.active ? root.items : []

            Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property var item: modelData
                readonly property bool quits: root.canQuit(item)
                readonly property bool leaving: TrayApps.isLeaving(item)
                readonly property bool stayed: TrayApps.didNotLeave(item)
                readonly property string iconSource: TrayApps.iconOf(item)
                // An empty pixmap (an app with no icon) shows the generic one
                readonly property bool iconOk: iconSource !== "" && chipIcon.status === Image.Ready && chipIcon.implicitWidth > 0

                visible: index < root.shown
                implicitWidth: chipRow.implicitWidth + 12
                implicitHeight: 26
                radius: height / 2
                color: chipMouse.containsMouse ? Theme.bg1 : Theme.bg
                opacity: leaving ? 0.5 : 1
                border.width: root.chipKeyOn("open", index) ? Theme.focusWidth : 0
                border.color: Theme.focusRing
                onImplicitWidthChanged: Qt.callLater(root.measure)

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton)
                            root.openMenu(chip.item)
                        else
                            root.open(chip.item)
                    }
                }
                RowLayout {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    spacing: 5

                    Item {
                        implicitWidth: 18
                        implicitHeight: 18

                        Image {
                            id: chipIcon
                            anchors.fill: parent
                            visible: chip.iconOk
                            source: chip.iconSource
                            sourceSize.width: 18
                            sourceSize.height: 18
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !chip.iconOk
                            text: String.fromCodePoint(0xF08C6)   // nf-md-application
                            textFormat: Text.PlainText
                            color: Theme.fg4
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize
                        }
                        // The app asks for attention
                        Rectangle {
                            visible: chip.item.status === Status.NeedsAttention
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: -2
                            width: 7
                            height: 7
                            radius: 3.5
                            color: Theme.yellow
                        }
                    }
                    Text {
                        Layout.maximumWidth: 96
                        text: chip.stayed ? "Não saiu" : Lists.trayName(chip.item)
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        color: chip.stayed ? Theme.red : Theme.fg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                    // The app's own quit entry
                    BarItem {
                        visible: chip.quits && !chip.leaving
                        implicitHeight: 18
                        text: String.fromCodePoint(0xF0156)   // nf-md-close
                        textColor: Theme.red
                        fontSize: Theme.fontSizeSmall
                        tooltip: "Sair pelo próprio app"
                        keyFocus: root.chipKeyOn("quit", chip.index)
                        onClicked: TrayApps.quit(chip.item)
                    }
                    Item {
                        visible: !chip.quits || chip.leaving
                        implicitWidth: 2
                    }
                }
            }
        }
        // The rest: opens the whole list in place
        Rectangle {
            visible: root.shown < root.items.length
            implicitWidth: Math.max(44, moreText.implicitWidth + 18)
            implicitHeight: 26
            radius: height / 2
            color: moreMouse.containsMouse ? Theme.bg2 : Theme.bg1
            border.width: root.chipKeyOn("more") ? Theme.focusWidth : 0
            border.color: Theme.focusRing

            Text {
                id: moreText
                anchors.centerIn: parent
                text: `+${root.items.length - root.shown}`
                textFormat: Text.PlainText
                color: Theme.fg2
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            MouseArea {
                id: moreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.setControlSection("background")
            }
        }
    }

    // ── The whole list, in place of the chips: a section of its own, in
    // the sections' card (Accordion) ──
    Accordion {
        open: root.expanded
        maxHeight: root.listMax
        Layout.leftMargin: -4
        Layout.rightMargin: -4

        ListBlock {
            id: listBlock
            visible: root.expanded
            maxHeight: Math.max(120, root.listMax - 120)

            Repeater {
                model: root.expanded ? root.items : []

                ListRow {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property var item: modelData
                    readonly property bool quits: root.canQuit(item)
                    readonly property bool leaving: TrayApps.isLeaving(item)
                    readonly property bool stayed: TrayApps.didNotLeave(item)

                    divider: index > 0
                    clickable: true
                    image: TrayApps.iconOf(item)
                    icon: String.fromCodePoint(0xF08C6)   // nf-md-application
                    dot: false
                    text: Lists.trayName(item)
                    note: item.status === Status.NeedsAttention ? "pede atenção" : ""
                    detail: stayed ? "Não saiu" : leaving ? "Saindo…" : ""
                    detailColor: stayed ? Theme.red : Theme.fg4
                    keyFocus: root.listKeyOn("open", index)
                    onClicked: root.open(item)
                    onKeyFocusChanged: {
                        if (keyFocus)
                            listBlock.reveal(row)
                    }

                    ListButton {
                        visible: row.item.hasMenu
                        compact: true
                        text: "Menu"
                        keyFocus: root.listKeyOn("menu", row.index)
                        onClicked: root.openMenu(row.item)
                    }
                    ListButton {
                        visible: row.quits && !row.leaving
                        compact: true
                        text: "Sair"
                        keyFocus: root.listKeyOn("quit", row.index)
                        onClicked: TrayApps.quit(row.item)
                    }
                }
            }
            ListRow {
                divider: true
                action: true
                clickable: true
                icon: String.fromCodePoint(0xF0143)   // nf-md-chevron_up
                text: "Mostrar menos"
                keyFocus: root.listKeyOn("less")
                onClicked: ShellState.closeControlSection()
            }
        }
    }

    // ── The app's menu, drawn here ──
    ListHeader {
        visible: root.menuItem !== null
        Layout.leftMargin: 0
        Layout.rightMargin: 0
        title: root.menuItem !== null ? Lists.trayName(root.menuItem) : ""
        detail: "menu do app"

        BarItem {
            implicitHeight: 18
            text: String.fromCodePoint(0xF0156)   // nf-md-close
            textColor: Theme.fg4
            fontSize: Theme.fontSizeSmall
            tooltip: "Fechar o menu"
            keyFocus: root.menuKeyOn("close")
            onClicked: root.closeMenu()
        }
    }
    ListBlock {
        id: menuBlock
        visible: root.menuItem !== null
        maxHeight: Math.max(120, root.listMax - 120)

        ListRow {
            visible: root.menuStack.length > 1
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF0141)   // nf-md-chevron_left
            text: "Voltar"
            keyFocus: root.menuKeyOn("back")
            onClicked: root.back()
        }
        Repeater {
            model: root.menuItem !== null ? menuReader.entries : []

            Item {
                id: entryItem
                required property var modelData
                required property int index
                readonly property var e: modelData

                Layout.fillWidth: true
                implicitHeight: e.isSeparator ? 9 : Theme.listRowHeight

                Rectangle {
                    visible: entryItem.e.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: Theme.bg2
                }
                ListRow {
                    visible: !entryItem.e.isSeparator
                    width: parent.width
                    divider: entryItem.index > 0 || root.menuStack.length > 1
                    clickable: entryItem.e.enabled
                    text: entryItem.e.text
                    textColor: entryItem.e.enabled ? Theme.fg : Theme.gray
                    icon: entryItem.e.check === "check" ? String.fromCodePoint(entryItem.e.checked ? 0xF0132 : 0xF0131)
                        : entryItem.e.check === "radio" ? String.fromCodePoint(entryItem.e.checked ? 0xF043E : 0xF043D) : ""
                    detail: entryItem.e.hasChildren && root.menuStack.length < Lists.TRAY_MENU_DEPTH
                            ? String.fromCodePoint(0xF0142) : ""   // nf-md-chevron_right
                    keyFocus: root.menuKeyOn("entry", entryItem.index)
                    onClicked: root.pressEntry(entryItem.e)
                    onKeyFocusChanged: {
                        if (keyFocus)
                            menuBlock.reveal(entryItem)
                    }
                }
            }
        }
    }
}
