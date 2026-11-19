pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.state
import "../control/lists.js" as Lists

// The apps running in the background, for the control center's "Em
// segundo plano" strip: the tray items (StatusNotifierItem; the shell is
// the tray host), the Passive ones left out, at most TRAY_MAX. Passive
// model: with the strip hidden nothing is read but the items themselves;
// the menus are read only while the strip shows (watch), and only the
// top level, to find the one quit entry for the × (lists.js
// trayQuitIndex; never on TRAY_NO_QUIT ids).
//
// What the shell does to an app is only what the app offers: activate()
// (open its window), a menu entry's triggered(), its own quit entry. Never
// a signal to a process (the item gives no owner). After the quit entry,
// the item has 5 s to go away; if it stays, it is marked "Não saiu" for
// 2 s. Clicks within 300 ms of the last one are ignored, and nothing runs
// while the session is locked.
Singleton {
    id: root

    readonly property bool locked: LockState.wanted || LockState.locked
    readonly property var items: Lists.trayItems(SystemTray.items.values, Status.Passive)

    // ── The strip showing: the menus' top level read ──
    property int watchers: 0
    function watch(on) {
        watchers = Math.max(0, watchers + (on ? 1 : -1))
    }

    // One reader per tray item (the host's own model, so a reader lives as
    // long as its item and is not made again when the list changes); it
    // reads only for an item shown that may get the ×
    property var readers: []
    Instantiator {
        model: SystemTray.items
        delegate: TrayMenu {
            required property var modelData
            readonly property var item: modelData
            menu: root.watchers > 0 && modelData.hasMenu && Lists.trayMayQuit(modelData.id)
                  && root.items.includes(modelData) ? modelData.menu : null
        }
        onObjectAdded: (i, o) => root.readers = root.readers.concat([o])
        onObjectRemoved: (i, o) => root.readers = root.readers.filter(r => r !== o)
    }
    // The item's quit entry (a QsMenuEntry), or null: none, ambiguous, or
    // not allowed
    function quitEntry(item) {
        if (!item || !Lists.trayMayQuit(item.id))
            return null
        const r = readers.find(x => x.item === item)
        if (!r)
            return null
        const i = Lists.trayQuitIndex(r.entries)
        return i >= 0 ? r.entries[i].entry : null
    }

    // An item's icon source, or "" for the generic one: lists.js trayIcon
    // (a plain theme name or the shell's own pixmap), and a theme name only
    // when the theme has it (else the "missing" checkerboard would show)
    function iconOf(item) {
        const src = item ? Lists.trayIcon(item.icon) : ""
        const name = src.startsWith("image://icon/") ? src.slice(13) : ""
        return name !== "" && Quickshell.iconPath(name, true) === "" ? "" : src
    }

    // ── Clicks ──
    property double lastAt: 0
    function allowed() {
        if (locked || Date.now() - lastAt < 300)
            return false
        lastAt = Date.now()
        return true
    }
    // Open the app: "menu" when the item is only a menu (the strip opens
    // its menu), "done" when asked, "" when refused
    function activate(item) {
        if (!item || !items.includes(item))
            return ""
        if (item.onlyMenu)
            return "menu"
        if (!allowed())
            return ""
        item.activate()
        return "done"
    }
    // A menu entry: the only thing the shell does with a menu
    function trigger(entry) {
        if (!entry || !entry.enabled || entry.hasChildren || entry.isSeparator || !allowed())
            return false
        entry.triggered()
        return true
    }

    // ── The × : the app's own quit entry ──
    // { item, at } waiting to go away, and those that did not
    property var leaving: []
    property var stayed: []
    function isLeaving(item) {
        return leaving.some(x => x.item === item)
    }
    function didNotLeave(item) {
        return stayed.some(x => x.item === item)
    }
    function quit(item) {
        const entry = quitEntry(item)
        if (!entry || isLeaving(item) || !allowed())
            return false
        entry.triggered()
        leaving = leaving.concat([{ item: item, at: Date.now() }])
        stayed = stayed.filter(x => x.item !== item)
        watcher.start()
        return true
    }
    property int leaveMs: 5000
    property int stayedMs: 2000
    Timer {
        id: watcher
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now()
            const all = Lists.toList(SystemTray.items.values)
            const still = root.leaving.filter(x => all.includes(x.item))
            const late = still.filter(x => now - x.at >= root.leaveMs)
            root.leaving = still.filter(x => now - x.at < root.leaveMs)
            root.stayed = root.stayed.filter(x => now - x.at < root.stayedMs && all.includes(x.item))
                .concat(late.map(x => ({ item: x.item, at: now })))
            if (root.leaving.length === 0 && root.stayed.length === 0)
                stop()
        }
    }
}
