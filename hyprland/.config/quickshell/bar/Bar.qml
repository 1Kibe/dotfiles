import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state
import qs.settings
import "edgemotion.js" as EdgeMotion
import "baritems.js" as BarItems

// The frame of one monitor: the top bar and the panel that hangs from it, drawn
// in one surface, so Hyprland blurs them as one shape. The window takes the
// whole screen and never changes size while the panels open and close (a resize
// shows one stretched frame of the bar; see `room`). Clicks reach it only where
// something is drawn (mask); the space under the bar is reserved by BarZone, so
// windows never move.
//
// The bar: one translucent strip with the windows' side gap and rounded
// (continuous) bottom corners. Its items go in three areas chosen in
// Configurações → Barra; by default, left: workspaces and the CPU, memory
// and temperature rings; center: the clock (an island with the music while a
// player plays); right: status and the power button.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    // Hyprland's view of this screen: its name is the key ShellState uses to
    // open a panel on this bar only, so every button below gets it
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property string monitorName: hyprMonitor ? hyprMonitor.name : ""

    // Where the panels (AttachedPanel) are drawn, and the bar they hang from.
    // Their shapes go to shapeLayer, between the bar's strip and the bar's
    // items, so a shape that takes the island's box (the music panel) stays
    // under the clock.
    readonly property alias panelLayer: panels
    readonly property alias shapeLayer: shapes
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
    // The room under the bar: the rest of the screen, always. The window
    // never changes size (each resize showed one squeezed or stretched frame
    // of the bar); it is clear and takes clicks only where something is
    // drawn (mask). Measured in the VM: 800 instead of 510 px high costs the
    // shell ~1 point of one CPU at rest, Hyprland nothing.
    readonly property real room: screen ? screen.height - Theme.barHeight : Theme.panelRoom

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

    // Print (T2b): the capture covers the screen in the Overlay layer, with
    // the frozen screen and its shade; the frame goes up over it while it is
    // open, so its pill (CapturePanel) hangs from the live bar. Hyprland puts
    // a surface that changes layer on top of that layer, without
    // re-creating it. It stays up until the pill has rolled back.
    readonly property bool overCapture: CaptureState.open || shown.some(p => p.overCapture)
    WlrLayershell.layer: overCapture ? WlrLayer.Overlay : WlrLayer.Top

    // Only the bar and the panels showing take clicks; over the capture, only
    // its pill (a click on the bar's strip starts a selection there instead
    // of opening a panel)
    mask: Region {
        item: root.overCapture ? null : bar
        regions: root.shown.map(p => p.maskRegion).concat([stretchLeftRegion, stretchRightRegion])
    }
    // The stretched ends take clicks too (empty while not stretched)
    readonly property Region stretchLeftRegion: Region { item: stretchLeftArea }
    readonly property Region stretchRightRegion: Region { item: stretchRightArea }
    Item {
        id: stretchLeftArea
        x: bar.x - width
        width: Math.round(Theme.gap * root.edgeLeft)
        height: Theme.barHeight
    }
    Item {
        id: stretchRightArea
        x: bar.x + bar.width
        width: Math.round(Theme.gap * root.edgeRight)
        height: Theme.barHeight
    }

    // A panel open here: the keyboard (Esc, the Wi-Fi password) and a click
    // outside, which closes it with its animation
    readonly property bool panelOpenHere: monitorName !== "" && ShellState.openPanel !== ""
                                          && ShellState.openOn === monitorName
    WlrLayershell.keyboardFocus: panelOpenHere ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // The grab gives the keyboard to the open panel at once (Esc); a click
    // outside closes the bar's panels, but not the settings: the windows
    // beside them stay usable
    HyprlandFocusGrab {
        id: grab
        active: root.panelOpenHere
        windows: [root]
        onCleared: {
            if (ShellState.openPanel !== "settings")
                ShellState.close()
        }
    }
    // A cleared grab turns itself off. With the settings still open nothing
    // else changes (panelOpenHere stays true), so the next panel opened here
    // gets the grab back: a new binding arms it again
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (root.panelOpenHere && !grab.active)
                grab.active = Qt.binding(() => root.panelOpenHere)
        }
    }
    Item {
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    // A panel that continues one of the bar's ends (ShellState.attachedLeft/
    // Right) squares that corner while it shows, so bar and panel read as one
    // shape; the bar's panels switch it with a short animation. A panel that
    // touches the screen's left or right edge (edgeSide, the settings on the
    // left) asks for more: the bar stretches that end over its side gap to the
    // screen's edge and squares that corner first, along the panel's own
    // timeline (its edgeStep, bar/EdgeTimeline), and goes back at the end of
    // its closing. Two panels on one side: the most open request wins
    readonly property bool edgeLeftAsked: EdgeMotion.sideAsked(shown, "left")
    readonly property bool edgeRightAsked: EdgeMotion.sideAsked(shown, "right")
    readonly property real edgeLeft: EdgeMotion.sideStep(shown, "left")
    readonly property real edgeRight: EdgeMotion.sideStep(shown, "right")
    property real cornerLeft: edgeLeftAsked ? Theme.barRadius * (1 - edgeLeft)
                              : monitorName !== "" && ShellState.attachedLeft === monitorName ? 0 : Theme.barRadius
    property real cornerRight: edgeRightAsked ? Theme.barRadius * (1 - edgeRight)
                               : monitorName !== "" && ShellState.attachedRight === monitorName ? 0 : Theme.barRadius
    Behavior on cornerLeft {
        enabled: !root.edgeLeftAsked
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
    }
    Behavior on cornerRight {
        enabled: !root.edgeRightAsked
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
    }

    // Print's overlay keeps its shade out of the bar's own shape (its side
    // gaps stay shaded): the shape now, on the focused monitor
    Binding {
        target: CaptureState
        property: "barShape"
        when: CaptureState.open && root.monitorName !== "" && root.monitorName === CaptureState.focusName
        value: ({ cornerLeft: root.cornerLeft, cornerRight: root.cornerRight,
                  stretchLeft: Theme.gap * root.edgeLeft, stretchRight: Theme.gap * root.edgeRight })
        restoreMode: Binding.RestoreNone
    }

    // The bar, with the same side gaps as the windows
    Item {
        id: bar
        x: Theme.gap
        width: root.width - 2 * Theme.gap
        height: Theme.barHeight

        // The window is clear; this shape paints the bar, so the rounded
        // bottom corners show what is behind them. Its ends reach the
        // screen's edges when a panel there asks for it
        BarStrip {
            anchors.fill: parent
            cornerLeft: root.cornerLeft
            cornerRight: root.cornerRight
            stretchLeft: Theme.gap * root.edgeLeft
            stretchRight: Theme.gap * root.edgeRight
        }

        // The panels' shapes (AttachedPanel), in the window's coordinates:
        // over the strip, under the bar's items
        Item {
            id: shapes
            x: -bar.x
            y: -bar.y
            width: root.width
            height: root.height
        }

        // The items, in the three areas chosen in Configurações → Barra
        // (bar/baritems.js). The center one sits on the middle of the whole
        // bar, not between the two others, so it stays put while they change
        // width
        BarArea {
            frame: root
            ids: root.areas.left
            anchors.left: parent.left
            anchors.leftMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
        }
        BarArea {
            frame: root
            ids: root.areas.center
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }
        BarArea {
            frame: root
            ids: root.areas.right
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // The panels hanging from the bar are moved here (AttachedPanel), above
    // the bar
    Item {
        id: panels
        anchors.fill: parent
    }

    // ── Items ──
    readonly property var areas: SettingsStore.ready
        ? BarItems.areas(SettingsStore.get("barLeft"), SettingsStore.get("barCenter"),
                         SettingsStore.get("barRight"), SettingsStore.get("barHidden"))
        : BarItems.areas(["workspaces", "system"], ["clock"],
                         ["recording", "volume", "network", "bluetooth", "battery", "power"], [])

    function itemComponent(id) {
        switch (id) {
        case "workspaces": return workspacesItem
        case "system": return systemItem
        case "clock": return clockItem
        case "recording": return recordingItem
        case "volume": return volumeItem
        case "network": return networkItem
        case "bluetooth": return bluetoothItem
        case "battery": return batteryItem
        case "power": return powerItem
        case "|": return separatorItem
        }
        return null
    }
    Component {
        id: workspacesItem
        Workspaces { monitor: root.hyprMonitor }
    }
    Component {
        id: systemItem
        SystemStatus { monitor: root.hyprMonitor }
    }
    // The clock, which becomes the music island; its panels (music,
    // Print's pill) hang from it wherever it is
    Component {
        id: clockItem
        CenterIsland { monitor: root.hyprMonitor }
    }
    // Only while recording the screen (Super+Alt+R)
    Component {
        id: recordingItem
        RecordingPill {}
    }
    // Each status button owns its panel; the monitor tells it which bar the
    // panel belongs to
    Component {
        id: volumeItem
        VolumeStatus { monitor: root.hyprMonitor }
    }
    Component {
        id: networkItem
        NetworkStatus { monitor: root.hyprMonitor }
    }
    Component {
        id: bluetoothItem
        BluetoothStatus { monitor: root.hyprMonitor }
    }
    Component {
        id: batteryItem
        BatteryStatus {}
    }
    Component {
        id: powerItem
        PowerButton { monitor: root.hyprMonitor }
    }
    Component {
        id: separatorItem
        Separator {}
    }

    // The settings (Super+S), on this monitor's left edge
    SettingsPanel {
        id: settingsPanel
        frame: root
        monitorName: root.monitorName
    }
}
