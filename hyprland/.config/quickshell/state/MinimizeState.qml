pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.state
import "../minimize/minimizelist.js" as List
import "../minimize/minact.js" as Act
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

    // ── What talks to Hyprland (the tests swap these) ──
    property var dispatch: text => Hyprland.dispatch(text)
    property var clientsNow: done => AreasState.clients(done)
    // monitor id -> name, and name -> active workspace id
    property var monitorsNow: () => Lists.toList(Hyprland.monitors.values).map(m => ({
        id: m.id, name: m.name, active: m.activeWorkspace ? m.activeWorkspace.id : 0
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
    // True when asked (the window is looked up and hidden right after);
    // false with refused(reason) when the address is not valid
    function minimize(address) {
        const a = Hypr.windowAddress(String(address || ""))
        if (a === "" || !Act.isAddress(a)) {
            refused("Essa janela não pode ser minimizada")
            return false
        }
        if (entries.some(e => e.address === a))
            return true
        clientsNow(list => root.hideFound(a, list))
        return true
    }
    function hideFound(address, list) {
        const c = Lists.toList(list).find(x => Hypr.windowAddress(String(x.address || "")) === address)
        if (!c) {
            refused("A janela não está mais aberta")
            return
        }
        const ws = c.workspace && typeof c.workspace === "object" ? c.workspace : {}
        if (typeof ws.name === "string" && ws.name.startsWith("special:")) {
            if (ws.name !== List.SPECIAL)
                refused("Essa janela está numa área escondida e não pode ser minimizada")
            return
        }
        const e = List.entryOf(c, monitorNames())
        if (e === null)
            return
        // Out of fullscreen or maximized first (it does not come back so)
        if (c.fullscreen === 2 || c.fullscreen === true)
            send(Act.unsetFullscreen(address, "fullscreen"))
        else if (c.fullscreen === 1)
            send(Act.unsetFullscreen(address, "maximized"))
        if (!send(Act.hide(address)))
            return
        entries = List.push(entries, e)
        minimized(address)
    }

    // ── Bring back ──
    // To the active workspace of the screen `monitorName` (the focused one
    // when not known), with the focus
    function restore(address, monitorName) {
        const a = Hypr.windowAddress(String(address || ""))
        if (a === "" || !entries.some(e => e.address === a) || !exists(a))
            return false
        const mons = monitorsNow()
        const mon = mons.find(m => m.name === monitorName) ?? mons.find(m => Hyprland.focusedMonitor && m.name === Hyprland.focusedMonitor.name) ?? mons[0]
        if (!mon || !Act.isWorkspace(mon.active))
            return false
        if (!send(Act.bringTo(a, mon.active)))
            return false
        send(Act.focus(a))
        entries = List.remove(entries, a)
        restored(a)
        return true
    }
    function restoreLast(monitorName) {
        const e = List.last(entries)
        return e !== null && restore(e.address, monitorName)
    }
    // Close a hidden window without bringing it back (it leaves the list
    // on its "closewindow" event)
    function close(address) {
        const a = Hypr.windowAddress(String(address || ""))
        return a !== "" && entries.some(e => e.address === a) && exists(a) && send(Act.close(a))
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
                entries = List.remove(entries, a)
                closed(a)
            }
        } else if (name === "urgent") {
            flag(d)
        } else if (name === "windowtitlev2") {
            const i = d.indexOf(",")
            const a = Hypr.windowAddress(d.slice(0, Math.max(0, i)))
            if (i > 0 && entries.some(e => e.address === a))
                entries = List.update(entries, a, { title: List.cut(d.slice(i + 1), List.TEXT_MAX) })
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            root.event(ev.name, ev.data)
        }
    }

    // ── A restart of the shell: the hidden windows, again ──
    function reload() {
        clientsNow(list => {
            const found = List.fromClients(Lists.toList(list), root.monitorNames())
            // Kept ones first (their order), then the found ones not listed
            const kept = root.entries.filter(e => found.some(f => f.address === e.address))
            root.entries = kept.concat(found.filter(f => !kept.some(e => e.address === f.address)))
        })
    }
    Component.onCompleted: Qt.callLater(reload)
}
