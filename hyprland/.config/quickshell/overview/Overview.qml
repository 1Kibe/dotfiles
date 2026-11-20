import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state
import "../control/lists.js" as Lists
import "../settings/hyprland.js" as Hypr

// The overview (Super+Tab): one window per screen over everything (the
// Overlay layer), shown while OverviewState.open, the keyboard only on the
// focused screen. Each screen shows its own windows, of the area it shows
// in its middle (OverviewScreen), and the same areas as the bar's
// workspaces (bar/Workspaces.qml): 1 to 5 always, the others with windows
// or active; with the areas together on every screen (AreasState), area N
// is workspace N*10+k on the screen in position k. Special workspaces
// (negative ids) never show.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property var mon: Hyprland.monitorFor(modelData)
        readonly property string name: modelData.name
        readonly property bool together: AreasState.together

        function areaOf(id) {
            return id >= 11 && id <= 209 && id % 10 !== 0 ? Math.floor(id / 10) : 0
        }
        // This screen's position among the areas' screens (together)
        readonly property int k: together && mon && mon.activeWorkspace && areaOf(mon.activeWorkspace.id) > 0
                                 ? mon.activeWorkspace.id % 10 : 0
        readonly property int activeWs: mon && mon.activeWorkspace ? mon.activeWorkspace.id : 0
        readonly property int shownWs: OverviewState.shownArea[name] ?? activeWs

        // The windows of a workspace, with their place on this screen
        function windowsOf(id) {
            if (!mon)
                return []
            return Lists.toList(Hyprland.toplevels.values)
                // Only this screen's: a workspace of another screen (areas
                // separate) shows its windows there, not here
                .filter(t => t && t.workspace && t.workspace.id === id && (!t.monitor || t.monitor === mon))
                .map(t => {
                    const o = t.lastIpcObject || {}
                    const at = o.at ? Lists.toList(o.at) : [0, 0]
                    const size = o.size ? Lists.toList(o.size) : [0, 0]
                    return { id: Hypr.windowAddress(t.address), title: t.title, appClass: o.class || "",
                             x: at[0] - mon.x, y: at[1] - mon.y, w: size[0], h: size[1], toplevel: t }
                })
                .filter(w => w.id !== "")
        }
        // Read while open and while the cards fly back
        readonly property bool showing: OverviewState.open || content.progress > 0
        readonly property var shownWindows: showing ? windowsOf(shownWs) : []
        // The strip's areas, as the bar's
        readonly property var stripAreas: {
            if (!showing || !mon)
                return []
            const ids = [1, 2, 3, 4, 5]
            for (const ws of Lists.toList(Hyprland.workspaces.values)) {
                const id = together ? areaOf(ws.id) : ws.id
                if (id > 5 && id <= 20 && (ws.active || Lists.toList(ws.toplevels.values).length > 0) && !ids.includes(id))
                    ids.push(id)
            }
            ids.sort((a, b) => a - b)
            // The screen in layout units (the windows' at and size use them)
            const sw = Math.max(1, mon.width / (mon.scale || 1)), sh = Math.max(1, mon.height / (mon.scale || 1))
            return ids.map(n => {
                // Together, a screen outside the areas (k 0) has no
                // workspace of them: nothing to drop on
                const wsId = together ? (k > 0 ? n * 10 + k : 0) : n
                const rects = wsId > 0 ? windowsOf(wsId).map(w => ({
                    x: w.x / sw, y: w.y / sh, w: w.w / sw, h: w.h / sh
                })) : []
                return { area: n, ws: wsId, label: String(n), shown: wsId === win.shownWs, rects: rects }
            })
        }

        // The first empty area's workspace on this screen (modules/areas.lua
        // empty(): together, the first area with no window on any screen;
        // separate, the first workspace id with no window)
        readonly property int emptyWs: {
            if (!showing)
                return 0
            const busy = {}
            for (const ws of Lists.toList(Hyprland.workspaces.values)) {
                if (Lists.toList(ws.toplevels.values).length > 0)
                    busy[together ? areaOf(ws.id) : ws.id] = true
            }
            for (let n = 1; n <= 20; n++) {
                if (!busy[n])
                    return together ? (k > 0 ? n * 10 + k : 0) : n
            }
            return 0
        }

        screen: modelData
        // Kept while the cards fly back
        visible: OverviewState.open || (content.progress > 0 && !OverviewState.locked)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        // The veil is the content's, fading with the flight
        color: Theme.clear
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overview"
        // The keyboard on the focused screen; with none known (right after a
        // screen comes or goes), on the first one
        WlrLayershell.keyboardFocus: OverviewState.open
                                     && (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === name
                                                                 : modelData === Quickshell.screens[0])
                                     ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        OverviewScreen {
            id: content
            anchors.fill: parent
            screenName: win.name
            windows: win.shownWindows
            areas: win.stripAreas
            minimizedCount: Lists.toList(ShellState.minimized).length
            emptyWs: win.emptyWs
            focus: true
            Keys.onPressed: event => {
                if (content.key(event))
                    event.accepted = true
            }
        }
    }
}
