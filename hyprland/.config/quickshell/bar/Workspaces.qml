import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.state

// Workspaces as dots: 1-5 always, 6 and up only with windows or while
// active. Active = a longer dash; with windows = a lighter dot.
// Click: go to the workspace. Wheel: previous/next, like Super+wheel.
//
// With the areas together on every screen (Configurações → Monitores,
// modules/areas.lua) the dots are areas: area N is workspace N*10+k on the
// screen in position k. Active = the area this screen shows; with windows
// = a window in that area on any screen. Click and wheel go through
// modules/areas.lua (a fixed Lua call with a whole number), so every screen
// changes at once.
RowLayout {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    spacing: 6

    // Ids to show, as text: the Repeater below is only rebuilt when the set
    // changes, so switching workspaces animates the dash
    readonly property bool together: AreasState.together
    // A workspace's area (0: not one of the areas' workspaces)
    function areaOf(id) {
        return id >= 11 && id <= 209 && id % 10 !== 0 ? Math.floor(id / 10) : 0
    }
    readonly property string key: {
        const ids = [1, 2, 3, 4, 5]
        for (const ws of Hyprland.workspaces.values) {
            // special workspaces (scratchpad) have negative ids
            const id = together ? areaOf(ws.id) : ws.id
            if (id > 5 && (ws.active || ws.toplevels.values.length > 0) && !ids.includes(id))
                ids.push(id)
        }
        return ids.sort((a, b) => a - b).join(",")
    }

    // The Hyprland config is Lua, so dispatch takes Lua
    function go(workspace) {
        if (together) {
            // modules/areas.lua: every screen at once; only whole numbers
            if (typeof workspace === "number" && Number.isInteger(workspace) && workspace >= 1 && workspace <= 20)
                Quickshell.execDetached(["hyprctl", "eval", `dotfiles_area.go(${workspace})`])
            else if (workspace === "e-1" || workspace === "e+1")
                Quickshell.execDetached(["hyprctl", "eval", `dotfiles_area.step(${workspace === "e-1" ? -1 : 1})`])
            return
        }
        // Ids go as-is; relative names like "e+1" need Lua quotes
        const value = typeof workspace === "number" ? workspace : `"${workspace}"`
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${value} })`)
    }

    Repeater {
        model: root.key.split(",").map(Number)

        Item {
            id: dot

            required property int modelData

            // The live workspace for this id; null for one of 1-5 that does not
            // exist yet (Hyprland only creates a workspace when it is used)
            readonly property var ws: {
                for (const w of Hyprland.workspaces.values) {
                    if (w.id === modelData)
                        return w
                }
                return null
            }
            // Together: every workspace of this area, on any screen
            readonly property var parts: root.together
                ? Hyprland.workspaces.values.filter(w => root.areaOf(w.id) === modelData) : []
            // Each monitor has its own active workspace: only this bar's counts
            readonly property bool here: root.together
                ? parts.some(w => w.active && w.monitor === root.monitor)
                : ws !== null && ws.active && ws.monitor === root.monitor
            readonly property bool busy: root.together
                ? parts.some(w => w.toplevels.values.length > 0)
                : ws !== null && ws.toplevels.values.length > 0

            // The active dot stretches into a dash, with a small spring bounce
            implicitWidth: here ? Theme.dotActiveWidth : Theme.dotSize
            implicitHeight: Theme.itemHeight
            Behavior on implicitWidth {
                SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.25 }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Theme.dotSize
                radius: height / 2
                // Hover first, then active, with windows, empty
                color: mouse.containsMouse ? Theme.text : dot.here ? Theme.dotActive : dot.busy ? Theme.dotBusy : Theme.dotEmpty
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: mouse

                property real wheel: 0   // touchpads send small steps: add them up

                anchors.fill: parent
                anchors.leftMargin: -3   // easier to hit
                anchors.rightMargin: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(dot.modelData)
                // Wheel up = previous. "e-1"/"e+1" step through the workspaces
                // open on the focused monitor, like Super+wheel.
                onWheel: event => {
                    wheel += event.angleDelta.y
                    while (wheel >= 120) {
                        wheel -= 120
                        root.go("e-1")
                    }
                    while (wheel <= -120) {
                        wheel += 120
                        root.go("e+1")
                    }
                }
            }

            Tooltip {
                target: dot
                text: `Área ${dot.modelData}`
                shown: mouse.containsMouse && !mouse.pressed
            }
        }
    }
}
