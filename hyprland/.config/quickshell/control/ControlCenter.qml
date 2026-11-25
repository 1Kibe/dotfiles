import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "sections.js" as Sections

// The control center: drops down from its button and continues the bar's
// right end. The top line (battery, settings, power) with the power section
// under it, the grid of buttons (sections.js) with their sections under it,
// the sliders (volume, with the mixer under it, and brightness) and, at the
// end, the apps running in the background (BackgroundStrip); one
// section open at a time (ShellState.controlSection). The keyboard moves
// over all of it (ControlKeys).
AttachedPanel {
    id: root

    panelWidth: Theme.controlWidth
    side: "right"

    // It never stays over the lock screen nor under a "Manter?" strip (which
    // takes the keyboard); ShellState.controlAllowed keeps it from opening
    // again while they last
    Connections {
        target: LockState
        function onWantedChanged() {
            if (LockState.wanted)
                ShellState.closeControl()
        }
        function onLockedChanged() {
            if (LockState.locked)
                ShellState.closeControl()
        }
    }
    Connections {
        target: MonitorsApply
        function onPendingChanged() {
            if (MonitorsApply.pending)
                ShellState.closeControl()
        }
    }
    Connections {
        target: KeyboardLayout
        function onPendingChanged() {
            if (KeyboardLayout.pending)
                ShellState.closeControl()
        }
    }

    // The monitor this center belongs to (its bar's)
    readonly property string monitorName: button && button.monitorName !== undefined ? button.monitorName : ""
    // The most a section grows: a part of the screen's height (it scrolls
    // inside past that)
    readonly property real listMax: frame && frame.screen ? frame.screen.height * Theme.controlListMax : 400

    // The grid's buttons drawn now (sections.js)
    readonly property var tiles: Sections.visible(Sections.SECTIONS, { dndAvailable: ShellState.dndAvailable })
    readonly property var night: Sections.nightText(NightLight.enabled, NightLight.start, NightLight.end, NightLight.wanted)
    // The Tailscale button shows the generic state read at each opening
    onOpenChanged: {
        if (open)
            Tailnet.readState()
    }

    // A button without a list, pressed by a click or a key
    function toggle(id) {
        if (id === "nightlight" && SettingsStore.ready)
            SettingsStore.set("nightLight", SettingsStore.get("nightLight") !== true)
        // Não perturbe: the notifications' own state (nothing kept here)
        else if (id === "dnd")
            NotificationState.toggleDnd()
    }

    // The minimize strip needs the room: only the section folds
    Connections {
        target: ShellState
        function onAccordionCollapseRequested(monitor) {
            if (monitor === root.monitorName && ShellState.controlOn === monitor)
                ShellState.closeControlSection()
        }
    }

    ControlTop {
        monitorName: root.monitorName
        keyIndex: keys.group === "top" && keys.keyFocus("top", keys.index) ? keys.index : -1
    }
    Accordion {
        open: root.open && ShellState.controlSection === "power"
        maxHeight: root.listMax

        PowerList {
            id: power
            active: root.open && ShellState.controlSection === "power"
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
        }
    }

    // The grid, two columns, no gap where a button is left out
    GridLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.topMargin: 4
        columns: 2
        columnSpacing: Theme.tileGap
        rowSpacing: Theme.tileGap

        Repeater {
            model: root.tiles

            ListTile {
                required property var modelData
                required property int index

                Layout.preferredWidth: 1
                icon: modelData.icon
                label: modelData.label
                hasArrow: modelData.hasList
                open: modelData.hasList && ShellState.controlSection === modelData.id
                on: (modelData.id === "nightlight" && NightLight.enabled) || (modelData.id === "tailscale" && Tailnet.backend === "Running")
                    || (modelData.id === "dnd" && NotificationState.dnd)
                warn: modelData.id === "updates" && Updates.summary.warn
                status: modelData.id === "nightlight" ? root.night.status
                      : modelData.id === "dnd" ? (NotificationState.dnd ? "Ligado" : "Desligado")
                      : modelData.id === "wifi" ? wifi.stateText
                      : modelData.id === "bluetooth" ? bluetooth.stateText
                      : modelData.id === "updates" ? Updates.summary.text
                      : modelData.id === "tailscale" ? Tailnet.summary : ""
                detail: modelData.id === "nightlight" ? root.night.hours : ""
                keyFocus: keys.keyFocus("grid", index)
                onClicked: {
                    if (modelData.hasList)
                        ShellState.setControlSection(modelData.id)
                    else
                        root.toggle(modelData.id)
                }
            }
        }
    }

    // The Wi-Fi section: the same list as the bar's network panel
    Accordion {
        open: root.open && ShellState.controlSection === "wifi"
        maxHeight: root.listMax

        NetworkList {
            id: wifi
            active: root.open && ShellState.controlSection === "wifi"
            maxListHeight: root.listMax - 120
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
            onKeysReleased: keys.reclaim()
        }
    }

    // The Bluetooth section: the same list as the bar's Bluetooth panel
    Accordion {
        open: root.open && ShellState.controlSection === "bluetooth"
        maxHeight: root.listMax

        BluetoothList {
            id: bluetooth
            active: root.open && ShellState.controlSection === "bluetooth"
            maxListHeight: Math.max(120, root.listMax - 240)
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
        }
    }

    // The updates section
    Accordion {
        open: root.open && ShellState.controlSection === "updates"
        maxHeight: root.listMax

        UpdatesList {
            id: updates
            active: root.open && ShellState.controlSection === "updates"
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
        }
    }

    // The Tailscale section
    Accordion {
        open: root.open && ShellState.controlSection === "tailscale"
        maxHeight: root.listMax

        TailscaleList {
            id: tailscale
            active: root.open && ShellState.controlSection === "tailscale"
            maxListHeight: Math.max(120, root.listMax - 260)
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
        }
    }

    // The sliders: the volume (its arrow folds out the mixer, under it) and
    // the brightness
    VolumeSlider {
        id: volume
        active: root.open
        keyPart: keys.keyFocus("sliders", 0) ? "slider" : keys.keyFocus("sliders", 1) ? "mixer" : ""
    }
    Accordion {
        open: root.open && ShellState.controlSection === "mixer"
        maxHeight: root.listMax

        AudioMixer {
            id: mixer
            active: root.open && ShellState.controlSection === "mixer"
            maxListHeight: Math.max(120, root.listMax - 260)
            keyIndex: keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
        }
    }
    BrightnessSlider {
        id: brightness
        keyFocus: keys.keyFocus("sliders", 2)
    }

    // The apps running in the background: chips, at the end
    BackgroundStrip {
        id: background
        active: root.open
        listMax: root.listMax
        chipKeyIndex: keys.group === "strip" && keys.keyFocus("strip", keys.index) ? keys.index : -1
        listKeyIndex: ShellState.controlSection === "background" && keys.group === "list" && keys.keyFocus("list", keys.index) ? keys.index : -1
    }

    ControlKeys {
        id: keys
        active: root.open
        monitorName: root.monitorName
        tiles: root.tiles
        sectionList: ShellState.controlSection === "power" ? power
                   : ShellState.controlSection === "wifi" ? wifi
                   : ShellState.controlSection === "bluetooth" ? bluetooth
                   : ShellState.controlSection === "mixer" ? mixer
                   : ShellState.controlSection === "updates" ? updates
                   : ShellState.controlSection === "tailscale" ? tailscale
                   : ShellState.controlSection === "background" ? background.listKeys : null
        onToggleRequested: id => root.toggle(id)
        volume: volume
        brightness: brightness
        strip: background
    }
}
