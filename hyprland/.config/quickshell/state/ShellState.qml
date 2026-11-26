pragma Singleton

import QtQuick
import Quickshell
import qs.theme

// Shared state of the shell's popups: one panel open at a time, on one
// monitor. Panels: "control" (control/ControlCenter, the button with the
// Arch symbol), "network", "volume", "bluetooth", "media", "system", and
// "settings" (settings/SettingsPanel, Super+S). "power" and "controlcenter"
// are other names of the control center ("power" opens it on its power
// section).
Singleton {
    id: root

    // Compared through isOpen() by each bar button; Bar.qml also reads them
    // directly for the keybind focus grab. Opening one panel replaces any
    // other, even on another monitor.
    property string openPanel: ""   // "" = all closed
    property string openOn: ""      // monitor name
    // Set by bar/MediaPanel, read by state/MediaState
    property string mediaPlayer: "" // dbusName of the player picked in the music panel
    // A panel that continues one of the bar's ends (bar/AttachedPanel: the
    // control center on the right) names its monitor here while it shows;
    // that bar squares the corner on that end
    property string attachedLeft: ""
    property string attachedRight: ""
    // The settings page asked for (IPC open(page), shell.qml); "" = the first
    property string settingsPage: ""
    // The monitor whose settings panel shows (opening, open or closing), for
    // bar/SettingsZone
    property string settingsOn: ""
    // The monitor whose clipboard drawer shows (opening, open or closing),
    // for clipboard/ClipboardZone
    property string clipboardOn: ""
    // The screens that have a bar ("Mostrar a barra em"; set by shell.qml).
    // The panels live in the bar: on a screen without one, a keybind opens
    // them on the first screen that has it
    property var barScreens: []
    function panelScreen(monitor) {
        if (barScreens.length === 0 || barScreens.includes(monitor))
            return monitor
        return barScreens[0]
    }

    // The panels a click, a keybind or the IPC may open; any other name is
    // ignored (a name from the IPC never lands in openPanel)
    readonly property var panels: ["control", "network", "volume", "bluetooth", "media", "system", "settings", "notifications"]
    function panelId(name) {
        if (name === "power" || name === "controlcenter")
            return "control"
        return panels.includes(name) ? name : ""
    }

    // ── The control center ──
    // Its sections, one open at a time ("" = all folded). Fixed ids only:
    // the IPC and the buttons pick from this list, nothing else does
    readonly property var controlSections: ["wifi", "bluetooth", "updates", "tailscale", "mixer", "power",
                                            "background", "github"]
    property string controlSection: ""
    // Opened by a key (Super+I, Super+X, the IPC) rather than a click: the
    // keyboard's ring shows at once on the first button
    property bool controlByKey: false
    // Não perturbe has a button only once the notifications module exists
    // (it owns that state; the control center only shows and switches it)
    property bool dndAvailable: false
    // The minimize strip asks the control center of `monitor` to fold its
    // section when it needs the room (it never reopens by itself)
    signal accordionCollapseRequested(string monitor)

    // ── Minimized windows (filled and answered by the minimize module) ──
    // [{ address, title, appId }]; empty until that module exists. The
    // overview only reads it and asks for a window back with the signal.
    // Whoever answers restoreMinimizedRequested(address) checks the address
    // (settings/hyprland.js windowAddress and ^0x[0-9a-f]{1,16}$) and that
    // the window is in Hyprland's list now, and only then builds the Lua;
    // title and appId never go into Lua, a command line or a log.
    property var minimized: []
    signal restoreMinimizedRequested(string address)

    // ── What reaches the screen's right edge, for the minimized strip ──
    // Per screen, the y where a bar panel reaching the right edge ends
    // (rightPanelEdge, from the top; with the bar at the bottom, from the
    // bottom up) and where a drawer from the bottom begins (bottomPanelEdge);
    // 0 or missing = nothing there. Replaced whole at each change.
    // Each panel publishes its own (owner): two panels of one screen
    // changing over never overwrite each other; the strip reads the one
    // reaching furthest into the screen (the largest y with the bar on top,
    // the smallest with the bar on the bottom)
    property var rightPanelEdges: ({})
    readonly property var rightPanelEdge: {
        const m = {}
        for (const key in rightPanelEdges) {
            const monitor = key.slice(0, key.indexOf("|"))
            const y = rightPanelEdges[key]
            m[monitor] = !(m[monitor] > 0) ? y : Theme.barAtBottom ? Math.min(m[monitor], y) : Math.max(m[monitor], y)
        }
        return m
    }
    // From the bottom (the clipboard drawer; any other, by its owner): the
    // strip reads the highest-reaching one (the smallest y)
    property var bottomPanelEdges: ({})
    readonly property var bottomPanelEdge: {
        const m = {}
        for (const key in bottomPanelEdges) {
            const monitor = key.slice(0, key.indexOf("|"))
            const y = bottomPanelEdges[key]
            m[monitor] = m[monitor] > 0 ? Math.min(m[monitor], y) : y
        }
        return m
    }
    function setRightPanelEdge(monitor, y, owner) {
        const key = `${monitor}|${owner || "panel"}`
        if ((rightPanelEdges[key] ?? 0) === y)
            return
        const m = Object.assign({}, rightPanelEdges)
        if (y > 0)
            m[key] = y
        else
            delete m[key]
        rightPanelEdges = m
    }
    // The same panels' body from left to right (the frame's x), so what
    // hangs under one of them (the notifications' pile) lines up with it;
    // same keys as rightPanelEdges
    property var rightPanelSpans: ({})
    // Monitors whose notifications' pile has a card coming in or leaving
    // right now (its room moving): the minimized strip steps aside meanwhile
    property var pileMoving: ({})
    function setPileMoving(monitor, on) {
        if (monitor === "" || (pileMoving[monitor] === true) === on)
            return
        const m = Object.assign({}, pileMoving)
        if (on)
            m[monitor] = true
        else
            delete m[monitor]
        pileMoving = m
    }
    function setRightPanelSpan(monitor, left, right, owner) {
        const key = `${monitor}|${owner || "panel"}`
        const old = rightPanelSpans[key]
        if (right > left ? old && old.left === left && old.right === right : !old)
            return
        const m = Object.assign({}, rightPanelSpans)
        if (right > left)
            m[key] = { left: left, right: right }
        else
            delete m[key]
        rightPanelSpans = m
    }
    // Overlay pieces with no state of their own (the capture's toast and
    // card) say when they show: the minimize picture is not taken then
    property var overlays: ({})
    readonly property bool overlayShown: Object.keys(overlays).length > 0
    function setOverlay(name, on) {
        if (!!overlays[name] === on)
            return
        const m = Object.assign({}, overlays)
        if (on)
            m[name] = true
        else
            delete m[name]
        overlays = m
    }
    // The minimized strip wants room on `monitor`: the control center folds
    // its section (it listens to accordionCollapseRequested); the strip then
    // closes the panel itself if that was not enough (closePanelOn)
    function requestRoom(monitor) {
        accordionCollapseRequested(monitor)
    }
    function closePanelOn(monitor) {
        if (openPanel !== "" && openOn === monitor)
            close()
    }
    function setBottomPanelEdge(monitor, y, owner) {
        const key = `${monitor}|${owner || "drawer"}`
        if ((bottomPanelEdges[key] ?? 0) === y)
            return
        const m = Object.assign({}, bottomPanelEdges)
        if (y > 0)
            m[key] = y
        else
            delete m[key]
        bottomPanelEdges = m
    }
    // The monitor whose control center is open ("" = closed)
    readonly property string controlOn: openPanel === "control" ? openOn : ""
    function controlOpen(monitor) {
        return isOpen("control", monitor)
    }
    // Never over the lock screen, nor while a "Manter?" strip waits for its
    // answer (it holds the keyboard: Esc and Enter would go to it)
    // Not under the overview either (it closes the panels when it opens;
    // a panel never opens beneath it)
    function controlAllowed() {
        return !LockState.locked && !LockState.wanted && !MonitorsApply.pending && !KeyboardLayout.pending
            && !OverviewState.open
    }
    // Opens it on `monitor` with `section` open ("" = all folded); false when
    // it may not open or the section is not one of the list
    function openControl(monitor, section, byKey) {
        const s = section === undefined ? "" : section
        if (monitor === "" || (s !== "" && !controlSections.includes(s)) || !controlAllowed())
            return false
        controlByKey = byKey === true
        openPanel = "control"
        openOn = monitor
        controlSection = s
        return true
    }
    // A section's button: opens it, closing the one that was open; the same
    // one again folds it
    function setControlSection(id) {
        if (openPanel !== "control" || !controlSections.includes(id))
            return
        controlSection = controlSection === id ? "" : id
    }
    function closeControlSection() {
        controlSection = ""
    }
    function closeControl() {
        if (openPanel === "control")
            close()
    }
    // Leaving the control center (closed or another panel) folds it: it
    // always opens with everything folded
    onOpenPanelChanged: {
        if (openPanel !== "control")
            controlSection = ""
    }

    // A click on a bar button (ControlButton, NetworkStatus, CenterIsland...)
    function toggle(panel, monitor, byKey) {
        if (panel === "power") {
            togglePower(monitor, byKey)
            return
        }
        const id = panelId(panel)
        if (id === "" || monitor === "" || OverviewState.open)
            return
        // The notifications never open locked or asked to lock (whatever asks)
        if (id === "notifications" && (LockState.locked || LockState.wanted))
            return
        if (isOpen(id, monitor)) {
            close()
        } else if (id === "control") {
            openControl(monitor, "", byKey)
        } else {
            openPanel = id
            openOn = monitor
        }
    }
    // Super+X and Ctrl+Alt+Del: the control center on its power section; the
    // same key again closes it, from another section it moves to power
    function togglePower(monitor, byKey) {
        if (isOpen("control", monitor) && controlSection === "power")
            close()
        else
            openControl(monitor, "power", byKey)
    }

    // The IPC handlers in shell.qml (keybinds and scripts). The same as a
    // click now: the panels live in the bar's own window (Bar.qml), whose
    // focus grab and keyboard work the same either way. Asked from a screen
    // with no bar, it opens on the bar's screen
    function toggleByKey(panel, monitor) {
        toggle(panel, panelScreen(monitor), true)
    }

    // Esc: in the control center first the open section, then the center;
    // any other panel closes at once
    function handleEscape() {
        if (openPanel === "control" && controlSection !== "")
            closeControlSection()
        else
            close()
    }

    // Esc, a click outside, a panel action that is done, or another popup
    // (clipboard, capture) opening
    function close() {
        openPanel = ""
        openOn = ""
    }

    // A bar whose monitor is not known yet (name "") is never open
    function isOpen(panel, monitor) {
        return monitor !== "" && openPanel === panel && openOn === monitor
    }
}
