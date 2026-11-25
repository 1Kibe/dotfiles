pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.theme
import "../notifications/safetext.js" as Safe
import "../notifications/policy.js" as Policy
import "../notifications/grouping.js" as Group
import "../notifications/imagepolicy.js" as Img
import "../overview/hypract.js" as HyprAct
import "../settings/hyprland.js" as Hypr

// The notifications of the session (the D-Bus server lives here). Every
// notification goes through one door, ingest(): the pace first, then the
// cleaning (notifications/safetext.js), the picture's rule
// (imagepolicy.js), the destination (policy.js); only then is it kept
// (tracked). What the screen and the list read is a plain copy of cleaned
// text (entries, screenList); the Quickshell's objects stay in a table of
// their own, used only to invoke a button and to dismiss. A replacement
// (same id) updates the entry in place only when it comes from the same
// app; from another app it is a new entry and the old one stays. An app
// closing its notification takes its card away and leaves the entry, with
// no buttons. Não perturbe is the only thing on disk
// (~/.local/state/quickshell/notifications.json, {"dnd": bool}). stats()
// and the log hold numbers and fixed words only.
Singleton {
    id: root

    // ── What the screen and the list read ──
    // Newest first: { id, appName, appKey, summary, body, urgent, time,
    // read, image: { kind, value }, actions: [{ text, index }], hasDefault,
    // closed }
    property var entries: []
    // The cards on screen, newest first: { id, appKey, urgent, count }
    property var screenList: []
    // Notifications that did not fit on screen (they wait in the list)
    property int moreCount: 0
    readonly property int unread: entries.reduce((n, e) => n + (e.read ? 0 : 1), 0)
    property bool dnd: false
    property bool serverOk: false
    property var dropped: ({ text: 0, rate: 0, cap: 0 })
    signal arrived(int id, string where)

    readonly property bool locked: LockState.locked || LockState.wanted
    // The focused monitor shows a full-screen window (the tests set it)
    property bool fullscreen: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.activeWorkspace !== null
                              && Hyprland.focusedMonitor.activeWorkspace.hasFullscreen

    // Entering a lock: the cards go at once (the entries stay)
    onLockedChanged: {
        if (locked)
            clearScreen()
    }
    // A full screen starting: the normal cards go to the list; leaving it
    // brings nothing back
    onFullscreenChanged: {
        if (fullscreen)
            setScreen(screenList.filter(c => c.urgent).slice(0, Policy.URGENT_FULLSCREEN_MAX))
    }

    // A recording starts: the cards on screen go to the list (never filmed)
    Connections {
        target: CaptureState
        function onRecordingChanged() {
            if (CaptureState.recording)
                root.clearScreen()
        }
    }

    // The control center's Não perturbe button shows only while this shell
    // is the session's notifications (it only shows and switches dnd)
    Binding {
        target: ShellState
        property: "dndAvailable"
        value: root.serverOk
    }

    // ── The server ──
    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: Img.IMAGES
        persistenceSupported: true
        inlineReplySupported: false
        onNotification: n => root.ingest(n)
    }

    // The Quickshell's objects by entry id; the entry id of each object
    property var objects: ({})
    property int serial: 0
    function entryOf(n) {
        for (const id in objects) {
            if (objects[id] === n)
                return Number(id)
        }
        return -1
    }

    // ── The door ──
    property var pace: null
    // All of them over the pace: nothing else is done (counted)
    function globalFull(now) {
        const all = pace ? pace.all.filter(t => t > now - Group.PACE_MS).length : 0
        return all >= Group.PACE_ALL
    }
    // This app's pace (and the global one): a new notification and an
    // update in place both go through it
    function admit(key, now) {
        if (globalFull(now))
            return false
        const p = Group.pace(pace, key, now)
        pace = p.pace
        return p.ok
    }
    function ingest(n) {
        const now = Date.now()
        // (1) The global pace, before any other work
        if (globalFull(now)) {
            count("rate")
            return
        }
        // (2) The cleaning; empty after it: dropped, spending no pace
        const copy = cleaned(n)
        const empty = copy.summary === "" && copy.body === ""
        // (3) This app's pace
        const ok = !empty && admit(copy.appKey, now)
        const where = Policy.decide({ urgent: copy.urgent, empty: empty },
                                    { overLimit: ok || empty ? "" : "rate", dnd: dnd, locked: locked, fullscreen: fullscreen,
                                      listOpen: ShellState.openPanel === "notifications" || CaptureState.recording })
        if (where === "drop") {
            count(Policy.dropReason({ empty: empty }, { overLimit: ok || empty ? "" : "rate" }))
            return
        }
        n.tracked = true
        keep(n, copy, now, where)
    }

    function count(reason) {
        const d = Object.assign({}, dropped)
        d[reason] = (d[reason] || 0) + 1
        dropped = d
    }

    // The plain copy of what may be shown
    function cleaned(n) {
        const entry = Safe.clean(n.desktopEntry, Safe.LIMITS.entry)
        const desktop = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(entry) ? entry : ""
        const app = Safe.clean(n.appName, Safe.LIMITS.app)
        const appName = app !== "" ? app : "Aplicativo"
        // At most the first 5 actions are read
        const actions = []
        let hasDefault = false
        const count = n.actions ? Math.min(5, n.actions.length) : 0
        for (let i = 0; i < count; i++) {
            const a = n.actions[i]
            if (a.identifier === "default") {
                hasDefault = true
                continue
            }
            if (a.identifier === "inline-reply")
                continue
            const text = Safe.clean(a.text, Safe.LIMITS.action)
            if (text !== "" && actions.length < 3)
                actions.push({ text: text, index: i })
        }
        const picture = Img.classify(n.image)
        return {
            appName: appName,
            appKey: Group.appKey(desktop, appName),
            summary: Safe.clean(n.summary, Safe.LIMITS.summary),
            body: Safe.cleanBody(n.body, Safe.LIMITS.body, Safe.LIST_LINES),
            urgent: n.urgency === NotificationUrgency.Critical,
            image: picture.kind !== "none" ? picture : Img.classify(n.appIcon),
            actions: actions,
            hasDefault: hasDefault
        }
    }

    function keep(n, copy, now, where) {
        const id = ++serial
        const e = Object.assign({ id: id, time: now, read: false, closed: false }, copy)
        const o = Object.assign({}, objects)
        o[id] = n
        objects = o
        watch(n)
        const t = Group.trim([e].concat(entries), Group.STORE_MAX, Group.STORE_PER_APP, id)
        for (const gone of t.removed)
            forget(gone, true)
        entries = t.store
        if (t.removed.length > 0) {
            const d = Object.assign({}, dropped)
            d.cap += t.removed.length
            dropped = d
        }
        // (never taken out by the caps; if it were: no card for it)
        if (!entries.some(x => x.id === id)) {
            forget(id, true)
            count("cap")
            return
        }
        if (where === "screen")
            toScreen(e)
        arrived(id, where)
    }

    // An object's own changes (a replacement, the app closing it)
    // (several objects can change in the same moment: a queue, not the
    // arguments of Qt.callLater, which keeps only the last ones)
    property var changedQueue: []
    // Each object is watched once (a replacement by another app keeps the
    // same object)
    property var watched: []
    function flushChanged() {
        const q = changedQueue
        changedQueue = []
        for (const n of q)
            replaced(n)
    }
    function watch(n) {
        if (watched.includes(n))
            return
        watched = watched.concat([n])
        const changed = () => {
            if (!root.changedQueue.includes(n))
                root.changedQueue = root.changedQueue.concat([n])
            Qt.callLater(root.flushChanged)
        }
        n.appNameChanged.connect(changed)
        n.desktopEntryChanged.connect(changed)
        n.summaryChanged.connect(changed)
        n.bodyChanged.connect(changed)
        n.urgencyChanged.connect(changed)
        n.imageChanged.connect(changed)
        n.actionsChanged.connect(changed)
        n.closed.connect(() => {
            root.closedByApp(n)
            root.watched = root.watched.filter(x => x !== n)
        })
    }
    function replaced(n) {
        const id = entryOf(n)
        if (id < 0)
            return
        const copy = cleaned(n)
        const old = entries.find(e => e.id === id)
        if (!old)
            return
        const now = Date.now()
        // The app key is what the message says (anyone can send any name):
        // it groups, it never proves who sent it
        if (copy.appKey === old.appKey) {
            // The same app: in place, not counted as new, through the same
            // pace (an update in a loop is capped like new ones); over it,
            // the older text stays
            if (!admit(copy.appKey, now)) {
                count("rate")
                return
            }
            // An update changes text and picture only: new or other buttons
            // are not taken (the click would go to whoever owned the id)
            const same = JSON.stringify(copy.actions) === JSON.stringify(old.actions) && copy.hasDefault === old.hasDefault
            const update = same ? copy : Object.assign({}, copy, { actions: [], hasDefault: false })
            entries = entries.map(e => e.id === id ? Object.assign({}, e, update, { read: false }) : e)
            return
        }
        // Another app over the same id: the old entry stays, without
        // buttons; the new one comes in like any other
        detach(id)
        const empty = copy.summary === "" && copy.body === ""
        const ok = !empty && admit(copy.appKey, now)
        const where = Policy.decide({ urgent: copy.urgent, empty: empty },
                                    { overLimit: ok || empty ? "" : "rate", dnd: dnd, locked: locked, fullscreen: fullscreen,
                                      listOpen: ShellState.openPanel === "notifications" || CaptureState.recording })
        if (where === "drop") {
            count(Policy.dropReason({ empty: empty }, { overLimit: ok || empty ? "" : "rate" }))
            n.dismiss()
            return
        }
        keep(n, copy, now, where)
    }
    function closedByApp(n) {
        const id = entryOf(n)
        if (id >= 0)
            detach(id)
    }
    // The entry stays, marked, with no buttons; its card goes
    function detach(id) {
        const o = Object.assign({}, objects)
        delete o[id]
        objects = o
        entries = entries.map(e => e.id === id ? Object.assign({}, e, { closed: true, actions: [], hasDefault: false }) : e)
        setScreen(screenList.filter(c => c.id !== id))
    }
    // An entry gone from the list (the X, the caps): its object dismissed
    function forget(id, dismiss) {
        const n = objects[id]
        const o = Object.assign({}, objects)
        delete o[id]
        objects = o
        if (dismiss && n)
            n.dismiss()
    }

    // ── The cards on screen ──
    function toScreen(e) {
        let list = screenList
        if (e.urgent && fullscreen && list.filter(c => c.urgent).length >= Policy.URGENT_FULLSCREEN_MAX)
            return
        list = Group.mergeOnScreen(list, { id: e.id, appKey: e.appKey, urgent: e.urgent }).list
        const r = Group.limitScreen(list, Theme.toastMax)
        moreCount += r.more
        setScreen(r.shown)
    }
    function setScreen(list) {
        screenList = list
        if (list.length === 0)
            moreCount = 0
    }
    function clearScreen() {
        setScreen([])
    }
    // Off the screen only (the entry stays in the list)
    function dismissToast(id) {
        setScreen(screenList.filter(c => c.id !== id))
    }

    // ── The list ──
    function markAllRead() {
        if (entries.some(e => !e.read))
            entries = entries.map(e => e.read ? e : Object.assign({}, e, { read: true }))
    }
    // Locked or asked to lock: nothing here acts (the IPC, a stale click)
    function dismiss(id) {
        if (locked)
            return false
        forget(id, true)
        entries = entries.filter(e => e.id !== id)
        setScreen(screenList.filter(c => c.id !== id))
        return true
    }
    function clearAll() {
        if (locked)
            return false
        for (const e of entries)
            forget(e.id, true)
        entries = []
        clearScreen()
        return true
    }
    // A button: the object's own action, only that one
    function invoke(id, index) {
        if (locked)
            return false
        const n = objects[id]
        const e = entries.find(x => x.id === id)
        if (!n || !e || !e.actions.some(a => a.index === index) || !n.actions || index >= n.actions.length)
            return false
        n.actions[index].invoke()
        return true
    }
    // The card's own click: the app's default action (if it sent one), the
    // card off the screen, read, and the app's window brought up
    function open(id) {
        if (locked)
            return false
        const e = entries.find(x => x.id === id)
        if (!e)
            return false
        if (e.hasDefault)
            activate(id)
        dismissToast(id)
        if (!e.read)
            entries = entries.map(x => x.id === id ? Object.assign({}, x, { read: true }) : x)
        bringWindow(e.appKey)
        return true
    }

    // ── The app's window: found by its class, focused by its address ──
    // What talks to Hyprland (the tests swap them): the clients, as
    // hyprctl -j clients gives them, and a dispatch of checked Lua
    property var clientsNow: done => AreasState.clients(done)
    property var dispatch: text => Hyprland.dispatch(text)
    // The class is only compared (exact, any case) with the app's key, and
    // only a key of the plain name rule; the focus goes by the window's
    // address, checked (overview/hypract.js). A window in a special
    // workspace (the minimized ones) or none: nothing happens
    function bringWindow(key) {
        if (typeof key !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(key))
            return false
        clientsNow(list => {
            if (root.locked || !Array.isArray(list))
                return
            const k = key.toLowerCase()
            const c = list.find(x => x && typeof x.class === "string" && x.class.toLowerCase() === k
                                     && !(x.workspace && String(x.workspace.name || "").startsWith("special")))
            if (!c)
                return
            const text = HyprAct.focusWindow(Hypr.windowAddress(String(c.address || "")))
            if (text !== null)
                root.dispatch(text)
        })
        return true
    }

    // The default action only (the card's click goes through open())
    function activate(id) {
        if (locked)
            return false
        const n = objects[id]
        const e = entries.find(x => x.id === id)
        if (!n || !e || !e.hasDefault)
            return false
        for (let i = 0; i < Math.min(5, n.actions.length); i++) {
            if (n.actions[i].identifier === "default") {
                n.actions[i].invoke()
                return true
            }
        }
        return false
    }

    // ── Não perturbe (kept on disk: only {"dnd": bool}) ──
    // Only an absolute folder (no HOME: nothing on disk)
    readonly property string stateBase: {
        const x = Quickshell.env("XDG_STATE_HOME") || ""
        const h = Quickshell.env("HOME") || ""
        return x.startsWith("/") ? x : h.startsWith("/") ? h + "/.local/state" : ""
    }
    readonly property string stateDir: stateBase !== "" ? `${stateBase}/quickshell` : ""
    readonly property string statePath: stateDir !== "" ? `${stateDir}/notifications.json` : ""
    property bool loaded: false
    // A switch asked before the file was read: applied after it
    property var asked: null
    function setDnd(on) {
        if (locked)
            return false
        if (!loaded) {
            asked = on === true
            return true
        }
        if (dnd === (on === true))
            return true
        dnd = on === true
        if (dnd)
            setScreen(screenList.filter(c => c.urgent && Policy.URGENT_PIERCES_DND))
        save()
        return true
    }
    function toggleDnd() {
        return setDnd(asked !== null ? !asked : !dnd)
    }
    function save() {
        if (!loaded || statePath === "")
            return
        stateFile.setText(JSON.stringify({ dnd: dnd }))
    }
    function load(text) {
        let ok = false
        if (typeof text === "string" && text.length <= 64) {
            try {
                const d = JSON.parse(text)
                ok = d !== null && typeof d === "object" && !Array.isArray(d) && Object.keys(d).length === 1 && typeof d.dnd === "boolean"
                if (ok)
                    dnd = d.dnd
            } catch (e) {
                ok = false
            }
        }
        if (!ok) {
            console.warn("notificacoes: notifications.json inválido, guardado como notifications.json.bak")
            Quickshell.execDetached(["mv", "-f", "--", statePath, statePath + ".bak"])
            dnd = false
        }
        afterLoad()
    }
    function afterLoad() {
        loaded = true
        if (asked !== null) {
            const on = asked
            asked = null
            setDnd(on)
        }
    }
    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (!root.loaded)
                root.load(text())
        }
        onLoadFailed: root.afterLoad()
        onSaved: Quickshell.execDetached(["chmod", "600", "--", root.statePath])
    }

    // ── Whose the name is: this shell's process, or another program ──
    readonly property string ownerScript: 'set -u\n'
        + 'exec 2>/dev/null\n'
        + 'q() { timeout 2 gdbus call --session -d org.freedesktop.DBus -o /org/freedesktop/DBus -m "org.freedesktop.DBus.$1" "$2"; }\n'
        + 'o=$(q GetNameOwner org.freedesktop.Notifications) || { echo no; exit 0; }\n'
        + 'o=${o#"(\'"}; o=${o%"\',)"}\n'
        + '[[ $o =~ ^:[0-9.]{1,20}$ ]] || { echo no; exit 0; }\n'
        + 'p=$(q GetConnectionUnixProcessID "$o") || { echo no; exit 0; }\n'
        + 'p=${p#"(uint32 "}; p=${p%",)"}\n'
        + '[ "$p" = "$PPID" ] && echo ok || echo no\n'
    // A diagnosis only (the sininho, stats), never a security decision.
    // Asked at 1.5, 5 and 15 s after start (a busy start can miss), then
    // every minute while another program has it; warned once, after the
    // second miss
    property bool warned: false
    property int misses: 0
    property int asks: 0
    readonly property var askAt: [1500, 3500, 10000]
    Process {
        id: owner
        command: ["bash", "-c", root.ownerScript]
        stdout: StdioCollector {
            onStreamFinished: {
                root.serverOk = text.trim() === "ok"
                root.misses = root.serverOk ? 0 : root.misses + 1
                if (root.misses >= 2 && !root.warned) {
                    root.warned = true
                    console.warn("notificacoes: outro programa de notificação tem o nome na sessão; recarregue o shell depois de fechar o outro")
                }
                if (!root.serverOk && root.asks < root.askAt.length)
                    ownerSoon.restart()
            }
        }
        stderr: StdioCollector {}
    }
    Timer {
        id: ownerSoon
        interval: root.askAt[Math.min(root.asks, root.askAt.length - 1)]
        running: true
        onTriggered: {
            root.asks++
            if (!owner.running)
                owner.running = true
        }
    }
    Timer {
        interval: 60000
        running: !root.serverOk && root.asks >= root.askAt.length
        repeat: true
        onTriggered: if (!owner.running) owner.running = true
    }
    Component.onCompleted: {
        if (stateDir !== "")
            Quickshell.execDetached(["sh", "-c", "umask 077; mkdir -p -- \"$1\"; chmod 700 -- \"$1\"", "sh", stateDir])
        else
            afterLoad()
    }

    // Numbers and yes/no only
    function stats() {
        return JSON.stringify({
            server: serverOk, total: entries.length, unread: unread, shown: screenList.length, more: moreCount,
            dnd: dnd, locked: locked, fullscreen: fullscreen,
            dropped: { text: dropped.text || 0, rate: dropped.rate || 0, cap: dropped.cap || 0 }
        })
    }
}
