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
        landing = ""
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

    // The windows Hyprland has now. windowsNow, dispatch, evalLua and send
    // are this file's own (and the tests', which swap the first three):
    // nothing else in the shell calls them
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
    // Go to a window and close the overview. With the areas together, its
    // area first, so every screen goes to that area (focusing the window
    // alone would leave the other screens on the old one)
    // The window gone to: its card flies back last (OverviewScreen)
    property string landing: ""
    function goTo(address) {
        const w = windowOf(address)
        if (!open || w === null)
            return false
        if (AreasState.together) {
            const ws = w.workspace ? w.workspace.id : 0
            const area = Act.areaOfWorkspace(ws, true)
            const here = Lists.toList(Hyprland.monitors.values).some(m => m && m.activeWorkspace
                                                                    && Act.areaOfWorkspace(m.activeWorkspace.id, true) === area)
            // Another area: the area and the focus in one eval, in order
            if (area > 0 && !here) {
                const text = Act.goToAreaAndFocus(area, address)
                if (text !== null)
                    evalLua(text)
                landing = address
                hide()
                return text !== null
            }
        }
        const ok = send(Act.focusWindow(address))
        landing = address
        hide()
        return ok
    }
    // Close a window; the overview stays open. The list is asked again
    // first (the refresh may still be on its way: the address is then
    // checked against the list as it was, a residual race)
    function closeWindow(address) {
        Hyprland.refreshToplevels()
        return open && windowOf(address) !== null && send(Act.closeWindow(address))
    }
    // Move a window to a workspace without following it
    function moveWindow(address, workspace) {
        Hyprland.refreshToplevels()
        return open && windowOf(address) !== null && send(Act.moveToWorkspace(address, workspace))
    }

    // Lua run by hyprctl eval (the areas together, modules/areas.lua); a
    // test swaps it
    property var evalLua: text => Quickshell.execDetached(["hyprctl", "eval", text])
    // Go to an area (every screen with the areas together) and close
    function goToArea(area) {
        if (!open)
            return false
        const text = AreasState.together ? Act.goToAreaTogether(area) : Act.goToArea(area)
        if (text === null)
            return false
        if (AreasState.together)
            evalLua(text)
        else
            dispatch(text)
        hide()
        return true
    }
    // A minimized window asked back (the minimize module answers the
    // signal): only open and unlocked, a checked address that is on the
    // minimized list now; then it closes
    function restoreMinimized(address) {
        if (!open || locked || !Act.isAddress(address))
            return false
        if (!Lists.toList(ShellState.minimized).some(m => m && m.address === address))
            return false
        ShellState.restoreMinimizedRequested(address)
        hide()
        return true
    }

    // "+": a new empty area, and close
    function newArea() {
        if (!open)
            return false
        if (AreasState.together)
            evalLua(Act.emptyAreaTogether())
        else
            dispatch(Act.emptyArea())
        hide()
        return true
    }
}
