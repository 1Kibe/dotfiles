import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "sections.js" as Sections

// The control center: drops down from its button and continues the bar's
// right end. The top line (battery, settings, power) with the power section
// under it, the grid of buttons (sections.js) with their sections under it,
// and the sliders (volume, with the mixer under it, and brightness); one
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

    // A button without a list, pressed by a click or a key
    function toggle(id) {
        if (id === "nightlight" && SettingsStore.ready)
            SettingsStore.set("nightLight", SettingsStore.get("nightLight") !== true)
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
                on: modelData.id === "nightlight" && NightLight.enabled
                status: modelData.id === "nightlight" ? root.night.status : ""
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

    // The sections of the grid's buttons, under it; their contents come in
    // the next steps
    Repeater {
        model: root.tiles.filter(t => t.hasList)

        Accordion {
            required property var modelData

            open: root.open && ShellState.controlSection === modelData.id
            maxHeight: root.listMax

            Text {
                Layout.fillWidth: true
                Layout.margins: 12
                text: "(em breve)"
                textFormat: Text.PlainText
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
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

        Text {
            Layout.fillWidth: true
            Layout.margins: 12
            text: "(em breve)"
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
    }
    BrightnessSlider {
        id: brightness
        keyFocus: keys.keyFocus("sliders", 2)
    }

    ControlKeys {
        id: keys
        active: root.open
        monitorName: root.monitorName
        tiles: root.tiles
        powerList: power
        volume: volume
        brightness: brightness
        onToggleRequested: id => root.toggle(id)
    }
}
