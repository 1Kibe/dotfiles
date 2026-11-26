pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.state
import "../minimize/minimizelist.js" as List
import "../minimize/minact.js" as Act
import "../minimize/slide.js" as Slide
import qs.theme
import "../settings/hyprland.js" as Hypr
import "../control/lists.js" as Lists

// The minimized windows. Super+H (or the app's own minimize button, the
// "minimized" event) hides the focused window in a special workspace that
// is never shown ("special:minimizadas"); it keeps running. It comes back
// to the active workspace of a screen, with the focus, by the strip on the
// right edge, Super+Shift+H (the last one), the overview's "Minimizadas"
// (ShellState.restoreMinimizedRequested) or another module (matchApp,
// restoreByApp). A window in fullscreen or maximized leaves that state
// first; one already in another special workspace is refused. After a
// restart of the shell the list is made again from the hidden windows,
// so a window never stays stuck there. Hiding and bringing back, the
// window does not move on the screen: Hyprland hides it and brings it at
// once, and its picture flies between its place and the wire
// (minimize/MinimizeFlight); coming back it is seen when the picture lands.
//
// Every Lua sent comes from minimize/minact.js: a checked address and
// whole numbers only. Every address (from a click, an event or another
// module) is checked against Hyprland's list of windows right then.
Singleton {
    id: root

    // In order of arrival (the last is Super+Shift+H's)
    property var entries: []
    // The strips' last moves, by screen, for "qs ipc call minimize stats"
    // (numbers only; filled by StripBody, never watched by a binding)
    readonly property var stripTrace: ({})
    signal minimized(string address)
    signal restored(string address)
    signal closed(string address)
    signal refused(string reason)

    // The overview reads the list (address, title, app) through ShellState
    onEntriesChanged: ShellState.minimized = entries.map(e => ({ address: e.address, title: e.title, appId: e.cls }))
    Connections {
        target: ShellState
        function onRestoreMinimizedRequested(address) {
            const m = Hyprland.focusedMonitor
            root.restore(address, m ? m.name : "")
        }
    }

    // Nothing runs while the session is locked (the app's own minimize
    // event, the IPC, the overview)
    readonly property bool locked: LockState.locked || LockState.wanted

    // ── What talks to Hyprland: dispatch, clientsNow, monitorsNow,
    // send is this file's own (and the tests', which swap
    // the first four); nothing else in the shell calls them ──
    property var dispatch: text => Hyprland.dispatch(text)
    property var clientsNow: done => AreasState.clients(done)
    // monitor id -> name, and name -> active workspace id
    property var monitorsNow: () => Lists.toList(Hyprland.monitors.values).map(m => ({
        // The size in layout units (the windows' at and size use them)
        id: m.id, name: m.name, active: m.activeWorkspace ? m.activeWorkspace.id : 0,
        x: m.x, y: m.y, w: Math.round(m.width / (m.scale || 1)), h: Math.round(m.height / (m.scale || 1)),
        special: !!(m.lastIpcObject && m.lastIpcObject.specialWorkspace && m.lastIpcObject.specialWorkspace.id)
    }))
    function send(text) {
        if (text === null)
            return false
        dispatch(text)
        return true
    }
    function monitorNames() {
        const m = {}
        for (const x of monitorsNow())
            m[x.id] = x.name
        return m
    }

    // ── Minimize ──
    // True when asked (the window is looked up, hidden and confirmed right
    // after); false with refused(reason) when it cannot be
    property var pending: []
    function minimize(address) {
        if (locked)
            return false
        const a = Hypr.windowAddress(String(address || ""))
        if (a === "" || !Act.isAddress(a)) {
            refused("Essa janela não pode ser minimizada")
            return false
        }
        if (entries.some(e => e.address === a) || pending.includes(a))
            return true
        pending = pending.concat([a])
        clientsNow(list => root.hideFound(a, list))
        return true
    }
    function hideFound(address, list) {
        const done = () => root.pending = root.pending.filter(x => x !== address)
        if (locked || Lists.toList(list).length === 0) {
            done()
            return
        }
        if (entries.some(e => e.address === address)) {
            done()
            return
        }
        const c = Lists.toList(list).find(x => Hypr.windowAddress(String(x.address || "")) === address)
        if (!c) {
            done()
            refused("A janela não está mais aberta")
            return
        }
        const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
        const e = List.entryOf(c, monitorNames(), AreasState.together)
        if (e === null) {
            done()
            return
        }
        // Already hidden with no entry (a restart): adopted
        if (ws.name === List.SPECIAL) {
            done()
            entries = List.push(entries, e)
            return
        }
        if (typeof ws.name === "string" && ws.name.startsWith("special:")) {
            done()
            refused("Essa janela está numa área escondida e não pode ser minimizada")
            return
        }
        // Pinned on every area: Hyprland may not move it; refused
        if (c.pinned === true) {
            done()
            refused("Uma janela fixada em todas as áreas não pode ser minimizada")
            return
        }
        // The preview's picture first (when the window can be seen whole),
        // then hidden
        if (canShot(c, Lists.toList(list))) {
            shoot(address, c, file => root.afterShot(address, e, file))
            return
        }
        hideNow(address, c, e)
    }
    // After grim (up to its deadline): the window as it is now (it may have
    // moved or closed); the picture goes to this entry only
    function afterShot(address, e, file) {
        clientsNow(list => {
            const all = Lists.toList(list)
            const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === address)
            if (root.locked || !c || all.length === 0) {
                if (file !== "")
                    Quickshell.execDetached(["rm", "-f", "--", file])
                root.pending = root.pending.filter(x => x !== address)
                return
            }
            // Covered meanwhile (a window over it, a panel): no picture
            if (file !== "" && !root.canShot(c, all)) {
                Quickshell.execDetached(["rm", "-f", "--", file])
                file = ""
            }
            e.shot = file
            root.hideNow(address, c, e)
        })
    }
    function hideNow(address, c, e) {
        const done = () => root.pending = root.pending.filter(x => x !== address)
        if (locked) {
            dropShot(address)
            done()
            return
        }
        // Hidden at once, with no animation of Hyprland's own: its picture
        // flies from its place to the wire instead (the window's props are
        // put back once Hyprland shows it hidden). One still coming back
        // stops its flight (its landing would show it again)
        dropFlights(address)
        quiet(address, false)
        // Out of fullscreen or maximized first (it does not come back so)
        const fs = Number(c.fullscreen) || 0
        if (fs & 2)
            send(Act.unsetFullscreen(address, "fullscreen"))
        else if (fs & 1)
            send(Act.unsetFullscreen(address, "maximized"))
        const mon = monitorsNow().find(m => m.id === c.monitor)
        const g = shotGeom(c)
        // Its screen, so its place can be moved to another one coming back
        if (mon)
            e.from = { x: mon.x, y: mon.y, w: mon.w, h: mon.h }
        // The picture first, over the window: the window is hidden once the
        // flight's layer has drawn it (flightShown), or after hideWaitMs
        if (mon && g) {
            const id = fly("out", address, e, { x: g.at[0] - mon.x, y: g.at[1] - mon.y, w: g.size[0], h: g.size[1] }, mon)
            hideWait = hideWait.concat([{ id: id, address: address, entry: e, due: Date.now() + hideWaitMs }])
            arm(hideWaitTimer, hideWait)
            return
        }
        hideSend(address, e)
    }
    function hideSend(address, e) {
        if (!send(Act.hide(address))) {
            dropFlights(address)
            unquiet(address)
            dropShot(address)
            root.pending = root.pending.filter(x => x !== address)
            return
        }
        // Listed only once Hyprland shows it in the hidden workspace
        confirm.push({ address: address, entry: e })
        confirmTimer.restart()
    }
    // Windows waiting for their picture to be on screen before hiding
    readonly property int hideWaitMs: 100
    property var hideWait: []
    // The layer drew a flight's picture (its first frame): its window hides now
    function flightShown(id) {
        const w = hideWait.find(x => x.id === id)
        if (!w)
            return
        hideWait = hideWait.filter(x => x !== w)
        arm(hideWaitTimer, hideWait)
        hideSend(w.address, w.entry)
    }
    Timer {
        id: hideWaitTimer
        onTriggered: {
            const now = Date.now() + 20
            const due = root.hideWait.filter(w => w.due <= now)
            root.hideWait = root.hideWait.filter(w => w.due > now)
            for (const w of due)
                root.hideSend(w.address, w.entry)
            root.arm(hideWaitTimer, root.hideWait)
        }
    }

    // ── The window's props while its picture flies ──
    // No animation of Hyprland's (and, coming back, invisible), with a tag
    // saying so: put back when it is hidden, when it has landed, on any
    // failure, and by a restart of the shell for a window left so. Hyprland
    // 0.57 cannot take an override back ("unset" is not a value of
    // set_prop): putting back sets opacity 1 (a multiplier: the decoration's
    // active and inactive opacity still apply) and no_anim off, which is what
    // every window has here (no window rule of this config sets either; a
    // rule added for one later would be overridden after a minimize)
    function quiet(address, invisible) {
        send(Act.tagProps(address, true))
        send(Act.noAnim(address, true))
        if (invisible)
            send(Act.seen(address, false))
    }
    function unquiet(address) {
        send(Act.seen(address, true))
        send(Act.noAnim(address, false))
        send(Act.tagProps(address, false))
    }
    function taggedProps(c) {
        return Lists.toList(c && c.tags).some(t => String(t).replace(/\*$/, "") === Act.PROPS_TAG)
    }

    // ── The flight (minimize/MinimizeFlight draws it) ──
    // { id, dir ("out" to the wire, "in" back), address, screen, from, to
    // ({ x, y, w, h } on that screen), shot, cls, due }. The layer reports
    // the end (flightDone); past `due` it ends all the same
    property var flights: []
    property int flightSeq: 0
    // The middle of each screen's wire (StripBody says; the screen's middle
    // when it is not out yet)
    property var wireAt: ({})
    function setWireAt(screen, y) {
        if (wireAt[screen] === y)
            return
        const m = Object.assign({}, wireAt)
        m[screen] = y
        wireAt = m
    }
    function fly(dir, address, e, rect, mon) {
        const s = Theme.minimizeFlyScale
        const wy = wireAt[mon.name] ?? mon.h / 2
        const wire = { x: mon.w - Theme.wireWidth / 2 - rect.w * s / 2, y: wy - rect.h * s / 2, w: rect.w * s, h: rect.h * s }
        // Reduce motion: no flight, the picture only fades where the window is
        const far = Theme.reduceMotion ? rect : wire
        flightSeq++
        const id = flightSeq
        flights = flights.concat([{
            id: id, dir: dir, address: address, screen: mon.name,
            from: dir === "out" ? rect : far, to: dir === "out" ? far : rect,
            shot: e && e.shot ? e.shot : "", cls: e ? e.cls : "",
            due: Date.now() + Theme.dur(Theme.minimizeFly) + root.flightSpareMs
        }])
        arm(flightTimer, flights)
        return id
    }
    readonly property int flightSpareMs: 500
    // A window's flights and its wait for a place, ended with nothing put
    // back (the caller sets its props)
    function dropFlights(address) {
        flights = flights.filter(f => f.address !== address)
        landWait = landWait.filter(w => w.address !== address)
        hideWait = hideWait.filter(w => w.address !== address)
        arm(flightTimer, flights)
        arm(landTimer, landWait)
        arm(hideWaitTimer, hideWait)
    }
    function flightDone(id) {
        const f = flights.find(x => x.id === id)
        if (!f)
            return
        flights = flights.filter(x => x.id !== id)
        arm(flightTimer, flights)
        // Landed: the window seen again, its picture no longer needed
        if (f.dir === "in") {
            unquiet(f.address)
            dropShot(f.address)
        }
    }
    // A timer set for the earliest item due (a later one never delays it)
    function arm(timer, items) {
        if (items.length === 0) {
            timer.stop()
            return
        }
        timer.interval = Math.max(20, Math.min(...items.map(w => w.due)) - Date.now())
        timer.restart()
    }
    Timer {
        id: flightTimer
        onTriggered: {
            const now = Date.now() + 20
            for (const f of root.flights.filter(x => x.due <= now))
                root.flightDone(f.id)
            root.arm(flightTimer, root.flights)
        }
    }
    // Locking with pictures flying: they end now, and a window coming back
    // is seen at once (under the lock)
    onLockedChanged: {
        if (!locked)
            return
        // Waiting for their picture: hidden now (never left in view)
        const toHide = hideWait
        hideWait = []
        hideWaitTimer.stop()
        for (const w of toHide)
            hideSend(w.address, w.entry)
        for (const f of flights)
            flightDone(f.id)
        const waiting = landWait
        landWait = []
        landTimer.stop()
        for (const w of waiting) {
            unquiet(w.address)
            dropShot(w.address)
        }
    }

    // Waits between the hide and its check (and between the two checks);
    // Hyprland not answering (an empty list, or hyprctl timing out): asked
    // again up to confirmTries times, then the window is given back
    readonly property int confirmMs: 200
    readonly property int confirmTries: 10
    property var confirm: []
    property bool confirmAsking: false
    // Not known to be hidden after all: back in view, its props back, refused
    function giveBack(w) {
        root.pending = root.pending.filter(x => x !== w.address)
        dropFlights(w.address)
        const mons = monitorsNow()
        const mon = mons.find(m => w.entry && m.name === w.entry.monitor) ?? mons[0]
        if (mon && Act.isWorkspace(mon.active) && !locked)
            send(Act.bringTo(w.address, mon.active))
        unquiet(w.address)
        dropShot(w.address)
        refused("A janela não foi minimizada")
    }
    Timer {
        id: confirmTimer
        interval: root.confirmMs
        onTriggered: {
            // One question at a time; the list is emptied only by its answer
            if (root.confirmAsking || root.confirm.length === 0)
                return
            const waiting = root.confirm.slice()
            root.confirmAsking = true
            root.clientsNow(list => {
                root.confirmAsking = false
                root.confirm = root.confirm.filter(w => !waiting.includes(w))
                const all = Lists.toList(list)
                // No answer from Hyprland: asked again, a few times
                if (all.length === 0) {
                    for (const w of waiting) {
                        const n = (w.empties ?? 0) + 1
                        if (n >= root.confirmTries)
                            root.giveBack(w)
                        else
                            root.confirm = root.confirm.concat([Object.assign({}, w, { empties: n })])
                    }
                    if (root.confirm.length > 0)
                        confirmTimer.restart()
                    return
                }
                for (const w of waiting) {
                    const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === w.address)
                    if (c && c.workspace && c.workspace.name === List.SPECIAL) {
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.unquiet(w.address)
                        root.entries = List.push(root.entries, w.entry)
                        root.minimized(w.address)
                    } else if (!c) {
                        // Closed meanwhile: nothing to say
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.dropFlights(w.address)
                        root.dropShot(w.address)
                    } else if ((w.tries ?? 0) < 1) {
                        // Late: one more look before giving up
                        root.confirm = root.confirm.concat([Object.assign({}, w, { tries: 1 })])
                    } else {
                        // Not hidden (it is still on its workspace): its props
                        // back, its picture no longer flying, refused
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.dropFlights(w.address)
                        root.unquiet(w.address)
                        root.dropShot(w.address)
                        root.refused("A janela não foi minimizada")
                    }
                }
                if (root.confirm.length > 0)
                    confirmTimer.restart()
            })
        }
    }

    // ── Bring back ──
    // To the active workspace of the screen `monitorName` (the focused one
    // when not known), with the focus; only a window that is still in the
    // hidden workspace (one taken elsewhere leaves the list, untouched).
    // It comes back invisible and with no animation of Hyprland's; once
    // Hyprland has placed it, its picture flies from the wire to that place
    // and the window is seen when it lands
    // Being brought back (a double click brings it once)
    property var restoring: []
    function restore(address, monitorName, fallback) {
        if (locked)
            return false
        const a = Hypr.windowAddress(String(address || ""))
        if (a === "" || !entries.some(e => e.address === a) || restoring.includes(a))
            return false
        const mons = monitorsNow()
        const mon = mons.find(m => m.name === monitorName) ?? mons.find(m => Hyprland.focusedMonitor && m.name === Hyprland.focusedMonitor.name) ?? mons[0]
        if (!mon || !Act.isWorkspace(mon.active))
            return false
        restoring = restoring.concat([a])
        clientsNow(list => {
            root.restoring = root.restoring.filter(x => x !== a)
            const all = Lists.toList(list)
            // No answer, or locked meanwhile: the entry stays
            if (all.length === 0 || root.locked)
                return
            const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === a)
            if (!c || !c.workspace || c.workspace.name !== List.SPECIAL) {
                // Gone or moved elsewhere: out of the list, nothing sent;
                // Super+Shift+H tries the one before
                root.dropShot(a)
                root.entries = List.remove(root.entries, a)
                if (fallback)
                    root.restoreLast(monitorName)
                return
            }
            // Its picture still flying to the wire: it turns back from here
            root.dropFlights(a)
            root.quiet(a, true)
            if (!root.send(Act.bringTo(a, mon.active))) {
                root.unquiet(a)
                return
            }
            const e = root.entries.find(x => x.address === a)
            // Hidden by an earlier version that slid it past the edge: to
            // its place (moved to this screen), tiled again if it was
            if (e && e.slid) {
                const b = Slide.back(e.at, e.size ?? (e.at ? [e.at.w, e.at.h] : null), e.from ?? null, mon, [])
                if (b)
                    root.send(Act.moveTo(a, b.to[0], b.to[1]))
                if (e.floating !== true) {
                    root.send(Act.float(a, false))
                    root.send(Act.tagTiled(a, false))
                }
            }
            root.send(Act.focus(a))
            root.entries = List.remove(root.entries, a)
            root.restored(a)
            root.landing(a, e, mon)
            // Checked as the hide is: still hidden (the move did not go
            // through), it is listed again
            root.restoreCheck = root.restoreCheck.concat([a])
            restoreCheckTimer.restart()
        })
        return true
    }
    // Where it lands, asked once Hyprland has placed it; no answer in
    // landMs: the place it had (moved to this screen)
    readonly property int landMs: 150
    property var landWait: []
    function landing(a, e, mon) {
        landWait = landWait.filter(w => w.address !== a).concat([{ address: a, entry: e, mon: mon, due: Date.now() + landMs }])
        arm(landTimer, landWait)
        clientsNow(list => {
            const w = root.landWait.find(x => x.address === a)
            if (!w)
                return
            root.landWait = root.landWait.filter(x => x !== w)
            root.arm(landTimer, root.landWait)
            const c = Lists.toList(list).find(x => Hypr.windowAddress(String(x.address || "")) === a)
            const g = c && c.workspace && c.workspace.name !== List.SPECIAL ? root.shotGeom(c) : null
            const at = g ? { x: g.at[0] - mon.x, y: g.at[1] - mon.y, w: g.size[0], h: g.size[1] } : root.keptPlace(e, mon)
            root.land(a, e, mon, at)
        })
    }
    function keptPlace(e, mon) {
        const size = e && e.at ? [e.at.w, e.at.h] : null
        const b = size ? Slide.back(e.at, size, e.from ?? null, mon, []) : null
        return b ? { x: b.to[0] - mon.x, y: b.to[1] - mon.y, w: size[0], h: size[1] } : null
    }
    function land(a, e, mon, at) {
        if (at && !root.locked) {
            root.fly("in", a, e, at, mon)
        } else {
            root.unquiet(a)
            root.dropShot(a)
        }
    }
    Timer {
        id: landTimer
        onTriggered: {
            const now = Date.now() + 20
            const due = root.landWait.filter(w => w.due <= now)
            root.landWait = root.landWait.filter(w => w.due > now)
            for (const w of due)
                root.land(w.address, w.entry, w.mon, root.keptPlace(w.entry, w.mon))
            root.arm(landTimer, root.landWait)
        }
    }
    property var restoreCheck: []
    Timer {
        id: restoreCheckTimer
        interval: root.confirmMs
        onTriggered: {
            // (one minimized again meanwhile is hidden on purpose)
            const list = root.restoreCheck.filter(a => !root.entries.some(e => e.address === a) && !root.pending.includes(a))
            root.restoreCheck = []
            if (list.length === 0)
                return
            root.clientsNow(cl => {
                const all = Lists.toList(cl)
                if (all.some(c => list.includes(Hypr.windowAddress(String(c.address || "")))
                                  && c.workspace && c.workspace.name === List.SPECIAL))
                    root.reload()
            })
        }
    }
    function restoreLast(monitorName) {
        if (locked)
            return false
        const e = List.last(entries.filter(x => !restoring.includes(x.address)))
        return e !== null && restore(e.address, monitorName, true)
    }
    // Close a hidden window without bringing it back (it leaves the list
    // on its "closewindow" event); only one still in the hidden workspace
    function close(address) {
        if (locked)
            return false
        const a = Hypr.windowAddress(String(address || ""))
        if (a === "" || !entries.some(e => e.address === a))
            return false
        clientsNow(list => {
            const all = Lists.toList(list)
            if (all.length === 0 || root.locked)
                return
            const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === a)
            if (c && c.workspace && c.workspace.name === List.SPECIAL) {
                root.send(Act.close(a))
            } else {
                root.dropShot(a)
                root.entries = List.remove(root.entries, a)
            }
        })
        return true
    }

    // ── For the strip and other modules ──
    function forMonitor(name) {
        const mons = monitorsNow()
        return List.forMonitor(entries, name, mons.map(m => m.name), mons.length > 0 ? mons[0].name : "")
    }
    function clearAttention(address) {
        if (entries.some(e => e.address === address && e.attention))
            entries = List.update(entries, address, { attention: false })
    }
    function flag(address) {
        const a = Hypr.windowAddress(String(address || ""))
        if (entries.some(e => e.address === a))
            entries = List.update(entries, a, { attention: true })
    }
    function matchApp(ids) {
        return List.matchApp(entries, ids)
    }
    function restoreByApp(ids, monitorName) {
        const e = matchApp(ids)
        return e !== null && restore(e.address, monitorName)
    }

    // ── Hyprland's events ──
    function event(name, data) {
        const d = String(data || "")
        if (name === "minimized") {
            // "ADDRESS,1": the app's own minimize button
            const [addr, on] = d.split(",")
            if (on === "1")
                minimize(addr)
        } else if (name === "closewindow") {
            const a = Hypr.windowAddress(d)
            // Closed while its picture flies or while it lands: nothing to
            // put back (the window is gone)
            if (flights.some(f => f.address === a) || landWait.some(w => w.address === a) || hideWait.some(w => w.address === a)) {
                dropFlights(a)
                dropShot(a)
                pending = pending.filter(x => x !== a)
            }
            if (entries.some(e => e.address === a)) {
                dropShot(a)
                entries = List.remove(entries, a)
                closed(a)
            }
        } else if (name === "urgent") {
            flag(d)
        } else if (name === "activespecial") {
            // "NAME,MONITOR": the hidden workspace shown (a hidden window
            // asked for the focus): hidden again, once (it is a toggle); the
            // window that takes the focus next wants attention
            const shown = d.split(",")[0]
            if (shown === List.SPECIAL && !hidingSpecial) {
                hidingSpecial = true
                awaitFocus = true
                send(Act.hideSpecial())
                hidingTimer.restart()
            } else if (shown !== List.SPECIAL) {
                hidingSpecial = false
            }
        } else if (name === "activewindowv2") {
            if (awaitFocus) {
                awaitFocus = false
                flag(d)
            }
        } else if (name === "windowtitlev2") {
            const i = d.indexOf(",")
            const a = Hypr.windowAddress(d.slice(0, Math.max(0, i)))
            if (i > 0 && entries.some(e => e.address === a))
                entries = List.update(entries, a, { title: List.cut(d.slice(i + 1), List.TEXT_MAX) })
        }
    }
    property bool hidingSpecial: false
    property bool awaitFocus: false
    readonly property int hidingMs: 500
    Timer {
        id: hidingTimer
        interval: root.hidingMs
        onTriggered: {
            root.hidingSpecial = false
            root.awaitFocus = false
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            root.event(ev.name, ev.data)
        }
    }

    // ── The preview's picture ──
    // Taken with grim on the window's place right before hiding it, small,
    // in a folder of the session's runtime directory (memory, 0700, checked
    // to be a real folder of this user), named by the checked address, 0600.
    // Only when the window can be seen whole: on its screen's active
    // workspace, inside the screen, no floating window over it, and no bar
    // panel, capture or clipboard drawer open (grim takes the composed
    // screen), never while locked. Deleted when the window comes back or
    // closes, and the whole folder when the shell starts.
    readonly property string shotDir: {
        const r = Quickshell.env("XDG_RUNTIME_DIR") || ""
        return /^\/[A-Za-z0-9._\/-]{1,200}$/.test(r) && !r.includes("..") ? r + "/qs-minimizar" : ""
    }
    function shotPath(address) {
        return shotDir !== "" && Act.isAddress(address) ? `${shotDir}/${address}.png` : ""
    }
    // Swapped by the tests (the panels and the windows "covering")
    // Anything drawn over the windows (grim takes the composed screen): a
    // bar panel, the capture and its toast/card, the clipboard, the
    // overview, the dimming before the lock, the confirm strips, the
    // monitors' numbers, the background picker, this strip open
    property var screenBusy: () => ShellState.openPanel !== "" || CaptureState.open || ClipboardStore.open
        || OverviewState.open || LockState.dimmed || MonitorsApply.pending || MonitorsApply.identifying
        || KeyboardLayout.pending || BackgroundStore.pickerOpen || ShellState.overlayShown
        || stripsOpen.some(n => monitorsNow().some(m => m.name === n))
        // A picture flying over the screen would be in the photo
        || flights.length > 0
    // The screens whose strip is open in icons or names (the strip says)
    property var stripsOpen: []
    function setStripOpen(screen, on) {
        const has = stripsOpen.includes(screen)
        if (on && !has)
            stripsOpen = stripsOpen.concat([screen])
        else if (!on && has)
            stripsOpen = stripsOpen.filter(x => x !== screen)
    }
    function canShot(c, list) {
        if (locked || shotDir === "" || screenBusy())
            return false
        // Coming back (invisible until its picture lands): no picture of it
        const a = Hypr.windowAddress(String(c && c.address || ""))
        if (flights.some(f => f.address === a) || landWait.some(w => w.address === a))
            return false
        const mons = monitorsNow()
        const mon = mons.find(m => m.id === c.monitor)
        const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
        if (!mon || mon.active !== ws.id || ![mon.x, mon.y, mon.w, mon.h].every(Number.isFinite))
            return false
        const g = shotGeom(c)
        if (!g)
            return false
        const at = g.at, size = g.size
        // Another window in fullscreen on this screen, or a special
        // workspace shown over it (a scratchpad): it would be the picture
        if (mon.special || list.some(o => o !== c && (Number(o.fullscreen) || 0) !== 0 && o.monitor === c.monitor
                                         && o.workspace && o.workspace.id === ws.id))
            return false
        // Whole inside its screen
        if (at[0] < mon.x || at[1] < mon.y || at[0] + size[0] > mon.x + mon.w || at[1] + size[1] > mon.y + mon.h)
            return false
        // No floating window of the same workspace, nor a pinned one of this
        // screen, over it (one with no sane place counts as over it)
        const over = list.some(o => {
            if (o === c || !(o.floating === true && o.workspace && o.workspace.id === ws.id
                             || o.pinned === true && o.monitor === c.monitor))
                return false
            const og = shotGeom(o)
            return !og || og.at[0] < at[0] + size[0] && at[0] < og.at[0] + og.size[0]
                       && og.at[1] < at[1] + size[1] && at[1] < og.at[1] + og.size[1]
        })
        return !over
    }
    // The window's place and size as whole numbers, or null
    function shotGeom(c) {
        const p = v => Array.isArray(v) && v.length === 2 ? v.map(List.whole) : null
        const at = p(c.at), size = p(c.size)
        if (!at || !size || at.some(n => !Number.isFinite(n)) || size.some(n => !Number.isFinite(n))
            || size[0] <= 0 || size[1] <= 0)
            return null
        return { at: at, size: size }
    }
    property var shotWaiting: null
    function shoot(address, c, then) {
        const file = shotPath(address)
        const g = shotGeom(c)
        if (file === "" || !g || shotJob.running) {
            then("")
            return
        }
        const at = g.at, size = g.size
        const scale = Math.min(1, 400 / size[0]).toFixed(3)
        shotWaiting = { address: address, file: file, then: then }
        shotJob.command = ["bash", "-c", root.shotScript, "bash", shotDir, file, `${at[0]},${at[1]} ${size[0]}x${size[1]}`, scale]
        shotTimeout.restart()
        shotJob.running = true
    }
    // The folder made and checked (a real folder, this user's, 0700), grim
    // with fixed options (no cursor), the file 0600
    readonly property string shotScript: [
        'umask 077',
        '[ -O "$(dirname -- "$1")" ] || exit 3',
        '[ -e "$1" ] || mkdir -m 700 -- "$1" || exit 3',
        '[ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] || exit 3',
        '[ "$(stat -c %a -- "$1")" = 700 ] || exit 3',
        'timeout 2 grim -g "$3" -s "$4" "$2" || { rm -f -- "$2"; exit 4; }',
        'chmod 600 -- "$2"'
    ].join("\n")
    Process {
        id: shotJob
        onExited: code => {
            shotTimeout.stop()
            const w = root.shotWaiting
            root.shotWaiting = null
            if (!w)
                return
            // Something came over the screen meanwhile (the lock, a
            // panel): the picture is not kept
            w.ok = code === 0 && !root.locked && !root.screenBusy()
            if (!w.ok)
                Quickshell.execDetached(["rm", "-f", "--", w.file])
            w.then(w.ok ? w.file : "")
        }
    }
    readonly property int shotMs: 2000
    Timer {
        id: shotTimeout
        interval: root.shotMs + 500
        onTriggered: shotJob.running = false
    }
    function dropShot(address) {
        const f = shotPath(address)
        if (f !== "")
            Quickshell.execDetached(["rm", "-f", "--", f])
    }

    // ── A restart of the shell: the hidden windows, again ──
    // Tried again (a few times) while the screens are not known yet
    property int reloads: 0
    function taggedTiled(c) {
        return Lists.toList(c && c.tags).some(t => String(t).replace(/\*$/, "") === Act.TILED_TAG)
    }
    function reload() {
        reloads++
        clientsNow(list => {
            const all = Lists.toList(list)
            const mons = root.monitorsNow()
            // Left with the flight's props by a restart (or anything else):
            // seen and animated again, whether hidden or not (one flying now
            // is left to its flight)
            for (const c of all) {
                const a = Hypr.windowAddress(String(c.address || ""))
                if (Act.isAddress(a) && root.taggedProps(c) && !root.flights.some(f => f.address === a)
                    && !root.landWait.some(w => w.address === a) && !root.pending.includes(a))
                    root.unquiet(a)
            }
            // Caught by a restart of an earlier version while sliding (out
            // of the hidden workspace, past its screen's edge): back to the
            // middle of its screen; if it was tiled is not known, it stays
            // floating
            if (!root.locked) {
                for (const c of all) {
                    const a = Hypr.windowAddress(String(c.address || ""))
                    if (!Act.isAddress(a) || !c.workspace || c.workspace.name === List.SPECIAL || !Slide.wasSlid(c, mons))
                        continue
                    const b = Slide.back(null, c.size, null, Slide.monitorOf(c, mons), [])
                    if (b)
                        root.send(Act.moveTo(a, b.to[0], b.to[1]))
                    if (root.taggedTiled(c)) {
                        root.send(Act.float(a, false))
                        root.send(Act.tagTiled(a, false))
                    }
                }
            }
            const found = List.fromClients(all, root.monitorNames(), AreasState.together).map(f => {
                // Slid out by an earlier version (past its screen's edge): it
                // comes back to the middle; tiled again if its tag says it
                // was tiled
                const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === f.address)
                if (c && Slide.wasSlid(c, mons))
                    return Object.assign({}, f, { slid: true, floating: !root.taggedTiled(c), from: null, size: [f.at.w, f.at.h] })
                return f
            })
            // Kept ones first (their order), then the found ones not listed
            const kept = root.entries.filter(e => found.some(f => f.address === e.address))
            for (const e of root.entries)
                if (!kept.includes(e))
                    root.dropShot(e.address)
            root.entries = kept.concat(found.filter(f => !kept.some(e => e.address === f.address)))
            if ((root.monitorsNow().length === 0 || all.length === 0) && root.reloads < 5)
                reloadTimer.restart()
        })
    }
    readonly property int reloadMs: 2000
    Timer {
        id: reloadTimer
        interval: root.reloadMs
        onTriggered: root.reload()
    }
    Component.onCompleted: {
        // Pictures of an earlier run never survive
        if (shotDir !== "")
            Quickshell.execDetached(["rm", "-rf", "--", shotDir])
        Qt.callLater(reload)
    }
}
