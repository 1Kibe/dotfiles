pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.state
import "../overview/hypract.js" as Act
import "../settings/hyprland.js" as Hypr
import "../control/lists.js" as Lists

// The overview (Super+Tab): open or not, the workspace each screen shows in
// its middle, and the window chosen (by the mouse or the arrows). The one
// target of the "overview" IPC. Never opens while the session is locked or
// a "Manter?" strip waits; locking closes it. Opening closes the bar's
// panels and the control center. Every action on a window checks its
// address against the windows Hyprland has right now, and sends only the
// fixed Lua of overview/hypract.js.
Singleton {
    id: root

    property bool open: false
    // screen name -> workspace id shown in that screen's middle
    property var shownArea: ({})
    // The chosen window's address ("" none)
    property string selected: ""

    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property bool busy: MonitorsApply.pending || KeyboardLayout.pending

    onLockedChanged: {
        if (locked)
            hide()
    }

    // "ok", or why not: "travada", "ocupada"
    function show() {
        if (locked)
            return "travada"
        if (busy)
            return "ocupada"
        ShellState.close()
        Hyprland.refreshToplevels()
        shownArea = activeAreas()
        selected = ""
        open = true
        return "ok"
    }
    function hide() {
        open = false
        shownArea = ({})
        selected = ""
    }
    function toggle() {
        if (open) {
            hide()
            return "ok"
        }
        return show()
    }

    // Each screen's active workspace
    function activeAreas() {
        const m = {}
        for (const mon of Lists.toList(Hyprland.monitors.values)) {
            if (mon && mon.activeWorkspace)
                m[mon.name] = mon.activeWorkspace.id
        }
        return m
    }
    function showArea(screenName, id) {
        if (!open || !Act.isWorkspace(id))
            return
        const m = Object.assign({}, shownArea)
        m[screenName] = id
        shownArea = m
    }

    // The windows Hyprland has now; a test swaps it
    property var windowsNow: () => Lists.toList(Hyprland.toplevels.values)
    // A window of that list (its address as "0x…"), or null
    function windowOf(address) {
        if (!Act.isAddress(address))
            return null
        return windowsNow().find(t => Hypr.windowAddress(t.address) === address) ?? null
    }
    function select(address) {
        if (address === "" || windowOf(address) !== null)
            selected = address
    }

    // ── Actions (checked, fixed Lua) ──
    // The dispatcher; a test swaps it
    property var dispatch: text => Hyprland.dispatch(text)
    function send(text) {
        if (text === null)
            return false
        dispatch(text)
        return true
    }
    // Go to a window (its workspace too) and close the overview
    function goTo(address) {
        if (!open || windowOf(address) === null)
            return false
        const ok = send(Act.focusWindow(address))
        hide()
        return ok
    }
    // Close a window; the overview stays open
    function closeWindow(address) {
        return open && windowOf(address) !== null && send(Act.closeWindow(address))
    }
    // Move a window to a workspace without following it
    function moveWindow(address, workspace) {
        return open && windowOf(address) !== null && send(Act.moveToWorkspace(address, workspace))
    }
}
