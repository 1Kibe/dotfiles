pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.state
import "../control/lists.js" as Lists

// The apps running in the background, for the control center's "Em
// segundo plano" strip: the tray items (StatusNotifierItem; the shell is
// the tray host), the Passive ones left out, at most TRAY_MAX. Passive
// model: with the control center closed nothing here is read (the host
// itself keeps each item's properties, read once when it registers); while
// it is open (watch) the list is made and the menus' top level read, to
// find the one quit entry for the × (lists.js trayQuitIndex; never on
// TRAY_NO_QUIT ids), checked again live right before the × acts.
//
// What the shell does to an app is only what the app offers: activate()
// (open its window), a menu entry's triggered(), its own quit entry. Never
// a signal to a process (the item gives no owner). After the quit entry,
// the item has 5 s to go away; if it stays, it is marked "Não saiu" for
// 2 s. Clicks within 300 ms of the last one are ignored, and nothing runs
// while the session is locked.
Singleton {
    id: root

    // The tray host from the shell's start (the apps see a tray at once and
    // register; nothing of them is read here until the center opens)
    readonly property var host: SystemTray
    readonly property bool locked: LockState.wanted || LockState.locked
    readonly property var items: watchers > 0 ? Lists.trayItems(SystemTray.items.values, Status.Passive) : []

    // ── The control center open: the list made, the menus' top level read ──
    property int watchers: 0
    function watch(on) {
        watchers = Math.max(0, watchers + (on ? 1 : -1))
        if (watchers === 0)
            forget()
    }

    // TRAY_MAX readers, one per place of the list (made once; each reads
    // the menu of the item now in its place, if it may get the ×)
    property var readers: []
    Instantiator {
        model: Lists.TRAY_MAX
        delegate: TrayMenu {
            required property int index
            readonly property var item: index < root.items.length ? root.items[index] : null
            menu: item !== null && item.hasMenu && Lists.trayMayQuit(item.id) ? item.menu : null
        }
        onObjectAdded: (i, o) => root.readers = root.readers.concat([o])
        onObjectRemoved: (i, o) => root.readers = root.readers.filter(r => r !== o)
    }
    function readerOf(item) {
        return item ? readers.find(x => x.item === item) ?? null : null
    }
    // The item's quit entry (a copy: { entry, text, ... }), or null: none,
    // ambiguous, or not allowed
    function quitCopy(item) {
        if (!item || !Lists.trayMayQuit(item.id))
            return null
        const r = readerOf(item)
        if (!r)
            return null
        const i = Lists.trayQuitIndex(r.entries)
        return i >= 0 ? r.entries[i] : null
    }
    function quitEntry(item) {
        const c = quitCopy(item)
        return c ? c.entry : null
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
        if (!item || !items.includes(item) || !allowed())
            return ""
        if (item.onlyMenu)
            return "menu"
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
        const shown = quitCopy(item)
        if (!shown || isLeaving(item) || !allowed())
            return false
        // The entry again, live: the same entry, still the one quit entry,
        // the same text, enabled, no children; anything changed, nothing
        // runs (the copy follows and the × goes away)
        const r = readerOf(item)
        const now = r ? r.live() : []
        const i = Lists.trayQuitIndex(now)
        if (i < 0 || now[i].entry !== shown.entry || now[i].text !== shown.text) {
            if (r)
                r.schedule()
            return false
        }
        shown.entry.triggered()
        leaving = leaving.concat([{ item: item, at: Date.now() }])
        stayed = stayed.filter(x => x.item !== item)
        watcher.start()
        return true
    }
    // The waits end with the center closing or the session locking
    function forget() {
        leaving = []
        stayed = []
        watcher.stop()
    }
    onLockedChanged: {
        if (locked)
            forget()
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
