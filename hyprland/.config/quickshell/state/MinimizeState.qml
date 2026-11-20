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
// so a window never stays stuck there.
//
// Every Lua sent comes from minimize/minact.js: a checked address and
// whole numbers only. Every address (from a click, an event or another
// module) is checked against Hyprland's list of windows right then.
Singleton {
    id: root

    // In order of arrival (the last is Super+Shift+H's)
    property var entries: []
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
    // windowsNow and send are this file's own (and the tests', which swap
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
    property var windowsNow: () => Lists.toList(Hyprland.toplevels.values)
    function exists(address) {
        return windowsNow().some(t => Hypr.windowAddress(String(t.address || "")) === address)
    }
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
        // A picture is only ever the one taken for this hide
        lastShot = ""
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
            shoot(address, c, () => root.hideNow(address, c, e))
            return
        }
        hideNow(address, c, e)
    }
    function hideNow(address, c, e) {
        const done = () => root.pending = root.pending.filter(x => x !== address)
        // Out of fullscreen or maximized first (it does not come back so)
        const fs = Number(c.fullscreen) || 0
        if (fs & 2)
            send(Act.unsetFullscreen(address, "fullscreen"))
        else if (fs & 1)
            send(Act.unsetFullscreen(address, "maximized"))
        // Seen on its screen: it slides out past the right edge first
        // (floating where it is, so it does not jump), then is hidden;
        // reduce motion, fullscreen or a screen to the right: at once
        const plan = Theme.reduceMotion ? null : Slide.out(c, monitorsNow())
        if (plan) {
            e.slid = true
            e.from = { x: plan.mon.x, y: plan.mon.y, w: plan.mon.w, h: plan.mon.h }
            e.size = plan.size
            if (c.floating !== true)
                send(Act.float(address, true))
            send(Act.resizeTo(address, plan.size[0], plan.size[1]))
            send(Act.moveTo(address, plan.at[0], plan.at[1]))
            send(Act.moveTo(address, plan.off[0], plan.off[1]))
            sliding = sliding.concat([{ address: address, entry: e, due: Date.now() + Theme.dur(Theme.minimizeSlide) }])
            slideTimer.restart()
            return
        }
        hideNowAfterSlide(address, e)
    }
    // ── The slide: windows on their way out, hidden when it ends ──
    property var sliding: []
    Timer {
        id: slideTimer
        interval: Theme.dur(Theme.minimizeSlide)
        onTriggered: {
            const now = Date.now()
            const due = root.sliding.filter(w => w.due <= now + 20)
            root.sliding = root.sliding.filter(w => w.due > now + 20)
            for (const w of due)
                root.hideNowAfterSlide(w.address, w.entry)
            if (root.sliding.length > 0) {
                interval = Math.max(20, Math.min(...root.sliding.map(w => w.due)) - now)
                restart()
            } else {
                interval = Theme.dur(Theme.minimizeSlide)
            }
        }
    }
    // A slid window not hidden after all: back to its place and state
    function slideBack(e) {
        if (!e || !e.slid || !e.at)
            return
        send(Act.moveTo(e.address, Math.round(e.at.x), Math.round(e.at.y)))
        if (e.floating !== true)
            send(Act.float(e.address, false))
    }
    function hideNowAfterSlide(address, e) {
        const done = () => root.pending = root.pending.filter(x => x !== address)
        if (!send(Act.hide(address))) {
            dropShot(address)
            lastShot = ""
            slideBack(e)
            done()
            return
        }
        // The picture, when one was taken for this window
        if (lastShot === shotPath(address)) {
            e.shot = lastShot
            lastShot = ""
        }
        // Listed only once Hyprland shows it in the hidden workspace
        confirm.push({ address: address, entry: e })
        confirmTimer.restart()
    }
    // Waits between the hide and its check (and between the two checks)
    readonly property int confirmMs: 200
    property var confirm: []
    Timer {
        id: confirmTimer
        interval: root.confirmMs
        onTriggered: {
            const waiting = root.confirm
            root.confirm = []
            root.clientsNow(list => {
                const all = Lists.toList(list)
                // No answer from Hyprland: not known yet, asked again
                if (all.length === 0) {
                    root.confirm = root.confirm.concat(waiting)
                    confirmTimer.restart()
                    return
                }
                for (const w of waiting) {
                    const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === w.address)
                    if (c && c.workspace && c.workspace.name === List.SPECIAL) {
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.entries = List.push(root.entries, w.entry)
                        root.minimized(w.address)
                    } else if (!c) {
                        // Closed meanwhile: nothing to say
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.dropShot(w.address)
                    } else if ((w.tries ?? 0) < 1) {
                        // Late: one more look before giving up
                        root.confirm = root.confirm.concat([Object.assign({}, w, { tries: 1 })])
                        confirmTimer.restart()
                    } else {
                        root.pending = root.pending.filter(x => x !== w.address)
                        root.dropShot(w.address)
                        root.slideBack(w.entry)
                        root.refused("A janela não foi minimizada")
                    }
                }
            })
        }
    }

    // ── Bring back ──
    // To the active workspace of the screen `monitorName` (the focused one
    // when not known), with the focus; only a window that is still in the
    // hidden workspace (one taken elsewhere leaves the list, untouched)
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
            if (!root.send(Act.bringTo(a, mon.active)))
                return
            // It slid out: it slides in from the right edge of this screen
            // to its place (moved to this screen), and is tiled again after
            const e = root.entries.find(x => x.address === a)
            const plan = e && e.slid && !Theme.reduceMotion
                ? Slide.back(e.at, e.size ?? (e.at ? [e.at.w, e.at.h] : null), e.from ?? null, mon, mons) : null
            if (plan) {
                root.send(Act.moveTo(a, plan.off[0], plan.off[1]))
                root.send(Act.moveTo(a, plan.to[0], plan.to[1]))
                if (e.floating !== true)
                    root.retile.push(a)
                retileTimer.restart()
            } else if (e && e.slid) {
                // Reduce motion: straight to its place
                const b = Slide.back(e.at, e.size ?? (e.at ? [e.at.w, e.at.h] : null), e.from ?? null, mon, [])
                if (b)
                    root.send(Act.moveTo(a, b.to[0], b.to[1]))
                if (e.floating !== true)
                    root.send(Act.float(a, false))
            }
            root.send(Act.focus(a))
            root.dropShot(a)
            root.entries = List.remove(root.entries, a)
            root.restored(a)
        })
        return true
    }
    // Slid in: tiled again once the slide ends
    property var retile: []
    Timer {
        id: retileTimer
        interval: Theme.dur(Theme.minimizeSlide)
        onTriggered: {
            const list = root.retile
            root.retile = []
            for (const a of list)
                root.send(Act.float(a, false))
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
        || KeyboardLayout.pending || BackgroundStore.pickerOpen || ShellState.overlayShown || stripsOpen.length > 0
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
        const mons = monitorsNow()
        const mon = mons.find(m => m.id === c.monitor)
        const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
        if (!mon || mon.active !== ws.id || mon.w === undefined)
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
        // No floating window of the same workspace over it
        const over = list.some(o => o !== c && o.floating === true && o.workspace && o.workspace.id === ws.id
            && Array.isArray(o.at) && Array.isArray(o.size)
            && o.at[0] < at[0] + size[0] && at[0] < o.at[0] + o.size[0]
            && o.at[1] < at[1] + size[1] && at[1] < o.at[1] + o.size[1])
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
        lastShot = ""
        if (file === "" || !g || shotJob.running) {
            then()
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
            root.lastShot = w.ok ? w.file : ""
            w.then()
        }
    }
    // The file of the last picture taken, picked up by the entry made next
    property string lastShot: ""
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
    function reload() {
        reloads++
        clientsNow(list => {
            const all = Lists.toList(list)
            const mons = root.monitorsNow()
            const found = List.fromClients(all, root.monitorNames(), AreasState.together).map(f => {
                // Slid out in an earlier run (past its screen's edge): it
                // slides back in to the middle, its tiling unknown (kept
                // floating)
                const c = all.find(x => Hypr.windowAddress(String(x.address || "")) === f.address)
                if (c && Slide.wasSlid(c, mons))
                    return Object.assign({}, f, { slid: true, floating: true, from: null, size: [f.at.w, f.at.h] })
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
