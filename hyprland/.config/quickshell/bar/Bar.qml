import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state
import "../theme/corners.js" as Corners

// The frame of one monitor: the top bar and the panel that hangs from it,
// drawn in one surface, so Hyprland blurs them as one shape (Ryan,
// 2026-11-10: "Sim, B"). The window takes the whole width and a fixed height:
// the bar plus Theme.panelRoom for the panels, so it never changes size while
// they open and close (a resize shows one stretched frame of the bar); it
// grows only if a panel needs more, and never shrinks. Clicks reach it only
// where something is drawn (mask); the space under it is reserved by
// BarZone, so windows never move.
//
// The bar: one translucent strip with the windows' side gap and rounded
// (continuous) bottom corners. Left: workspaces and the CPU, memory and
// temperature rings. Center: the clock (an island with the music while a
// player plays). Right: status and the power button.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    // Hyprland's view of this screen: its name is the key ShellState uses to
    // open a panel on this bar only, so every button below gets it
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property string monitorName: hyprMonitor ? hyprMonitor.name : ""

    // Where the panels (AttachedPanel) are drawn, and the bar they hang from
    readonly property alias panelLayer: panels
    readonly property alias barArea: bar

    // Panels showing on this bar (opening, open or closing): they set the
    // window's height and the clickable area
    property var shown: []
    function showPanel(panel) {
        if (!shown.includes(panel))
            shown = shown.concat([panel])
    }
    function hidePanel(panel) {
        shown = shown.filter(p => p !== panel)
    }
    readonly property real panelRoom: shown.reduce((room, p) => Math.max(room, p.roomHeight), 0)
    // The room under the bar: grows (never shrinks) when a panel needs more
    property real room: Theme.panelRoom
    onPanelRoomChanged: {
        if (panelRoom > room)
            room = Math.ceil(panelRoom)
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight + room
    // BarZone reserves the bar's height (Hyprland adds gaps_out below it)
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.namespace: "quickshell-bar"

    // Only the bar and the panels showing take clicks
    mask: Region {
        item: bar
        regions: root.shown.map(p => p.maskRegion)
    }

    // A panel open here: the keyboard (Esc, the Wi-Fi password) and a click
    // outside, which closes it with its animation
    readonly property bool panelOpenHere: monitorName !== "" && ShellState.openPanel !== ""
                                          && ShellState.openOn === monitorName
    WlrLayershell.keyboardFocus: panelOpenHere ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    HyprlandFocusGrab {
        active: root.panelOpenHere
        windows: [root]
        onCleared: ShellState.close()
    }
    Item {
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    // A panel that continues one of the bar's ends (ShellState.attachedLeft/
    // Right) squares that corner while it shows, so bar and panel read as
    // one shape
    property real cornerLeft: monitorName !== "" && ShellState.attachedLeft === monitorName ? 0 : Theme.barRadius
    property real cornerRight: monitorName !== "" && ShellState.attachedRight === monitorName ? 0 : Theme.barRadius
    Behavior on cornerLeft {
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
    }
    Behavior on cornerRight {
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
    }

    // The bar, with the same side gaps as the windows
    Item {
        id: bar
        x: Theme.gap
        width: root.width - 2 * Theme.gap
        height: Theme.barHeight

        // The window is clear; this shape paints the bar, so the rounded
        // bottom corners show what is behind them (continuous corners, like
        // the panels', theme/corners.js)
        Shape {
            id: strip
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.barFill
                strokeWidth: -1
                PathSvg {
                    path: {
                        const w = strip.width, h = strip.height, s = Theme.cornerSmoothing
                        return `M 0 0 L ${w} 0 `
                            + Corners.corner(w, h, 0, 1, -1, 0, root.cornerRight, s)
                            + Corners.corner(0, h, -1, 0, 0, -1, root.cornerLeft, s)
                            + "Z"
                    }
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            Workspaces {
                monitor: root.hyprMonitor
            }
            Separator {}
            SystemStatus {
                monitor: root.hyprMonitor
            }
        }

        // Centered on the whole bar, not between the two rows, so the clock
        // stays put while the side rows change width. Top-anchored: the
        // island fills the full bar height.
        CenterIsland {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            monitor: root.hyprMonitor
        }

        RowLayout {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            // Only while recording the screen (Super+Alt+R)
            RecordingPill {}
            // Each status button owns its panel; the monitor tells it which
            // bar the panel belongs to
            VolumeStatus {
                monitor: root.hyprMonitor
            }
            NetworkStatus {
                monitor: root.hyprMonitor
            }
            BluetoothStatus {
                monitor: root.hyprMonitor
            }
            BatteryStatus {}
            Separator {}
            PowerButton {
                monitor: root.hyprMonitor
            }
        }
    }

    // The panels hanging from the bar are moved here (AttachedPanel), above
    // the bar
    Item {
        id: panels
        anchors.fill: parent
    }
}
