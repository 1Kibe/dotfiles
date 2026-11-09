import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.theme

// Workspaces as dots: 1-5 always, 6 and up only with windows or while
// active. Active = a longer dash; with windows = a lighter dot.
// Click: go to the workspace. Wheel: previous/next, like Super+wheel.
RowLayout {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    spacing: 6

    // Ids to show, as text: the Repeater below is only rebuilt when the set
    // changes, so switching workspaces animates the dash
    readonly property string key: {
        const ids = [1, 2, 3, 4, 5]
        for (const ws of Hyprland.workspaces.values) {
            // special workspaces (scratchpad) have negative ids
            if (ws.id > 5 && (ws.active || ws.toplevels.values.length > 0))
                ids.push(ws.id)
        }
        return ids.sort((a, b) => a - b).join(",")
    }

    // The Hyprland config is Lua, so dispatch takes Lua
    function go(workspace) {
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
            // Each monitor has its own active workspace: only this bar's counts
            readonly property bool here: ws !== null && ws.active && ws.monitor === root.monitor
            readonly property bool busy: ws !== null && ws.toplevels.values.length > 0

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
