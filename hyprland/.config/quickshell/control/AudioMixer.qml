import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.bar
import "lists.js" as Lists

// The mixer, in the control center's mixer section (under the volume
// slider) and in the bar's volume panel: the output devices, the
// microphone (mute, level and its devices) and one control per app playing
// sound (icon, name, mute, level), the apps scrolling inside past
// maxListHeight. In the bar's panel the output's own level shows on top too
// (outputLevel). Nodes are tracked (volume and mute only work on tracked
// nodes) only while the list shows, at most MAX_STREAMS apps; closed,
// nothing is tracked. A level is never written above 100%. The default
// device changes only to a node of the list itself. Names from outside go
// through lists.js and show as plain text; an app's icon only by a theme
// name.
ColumnLayout {
    id: root

    // The list showing (its panel or section open)
    required property bool active
    // The default output's mute and level on top (the bar's panel)
    property bool outputLevel: false
    property real maxListHeight: 240
    // The item the control center's keyboard is on (-1 none); see keyItems
    property int keyIndex: -1

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var m: Lists.mixer(Pipewire.nodes.values)
    // What is tracked: everything listed, only while the list shows (the
    // tracker's own list sends no change signal, so the count is kept here)
    readonly property var tracked: active ? m.sinks.concat(m.sources, m.streams) : []
    readonly property int trackedCount: tracked.length

    PwObjectTracker {
        objects: root.tracked
    }

    // Only a node of the list itself becomes the default
    function makeDefault(node, output) {
        if (!active || !node)
            return
        if (output && m.sinks.includes(node))
            Pipewire.preferredDefaultAudioSink = node
        else if (!output && m.sources.includes(node))
            Pipewire.preferredDefaultAudioSource = node
    }
    function live(node) {
        return node !== null && node !== undefined && node.ready && node.audio !== null
    }
    function setVolume(node, v) {
        if (active && live(node))
            node.audio.volume = Lists.clampVolume(v)
    }
    function toggleMute(node) {
        if (active && live(node))
            node.audio.muted = !node.audio.muted
    }

    // ── The control center's keyboard ──
    readonly property var keyItems: Lists.mixerKeys(m, live(source))
    readonly property int keyCount: keyItems.length
    function keyOn(kind, i) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind && (i === undefined || it.index === i)
    }
    // Enter: a device becomes the default; on the microphone or an app, mute
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "sink")
            makeDefault(m.sinks[it.index], true)
        else if (it.kind === "source")
            makeDefault(m.sources[it.index], false)
        else if (it.kind === "micMute")
            toggleMute(source)
        else if (it.kind === "stream")
            toggleMute(m.streams[it.index])
    }

    component Caption: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    // A mute button, a slider (0..100%) and the percent, for one node
    component Level: RowLayout {
        id: level
        required property var node
        property string onIcon: String.fromCodePoint(0xF057E)     // nf-md-volume_high
        property string offIcon: String.fromCodePoint(0xF075F)    // nf-md-volume_off
        property bool muteFocus: false
        readonly property bool ok: root.live(node)
        readonly property bool muted: ok && node.audio.muted

        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        spacing: 6

        BarItem {
            text: level.muted || !level.ok ? level.offIcon : level.onIcon
            textColor: !level.ok ? Theme.gray : level.muted ? Theme.red : Theme.text
            tooltip: level.muted ? "Ativar o som" : "Silenciar"
            keyFocus: level.muteFocus
            onClicked: root.toggleMute(level.node)
        }
        PanelSlider {
            Layout.fillWidth: true
            enabled: level.ok
            value: level.ok ? Math.min(1, level.node.audio.volume) : 0
            muted: level.muted
            onMoved: v => root.setVolume(level.node, v)
        }
        // Fixed width so the slider does not jump as the digits change
        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: level.ok ? `${Math.round(level.node.audio.volume * 100)}%` : ""
            color: level.muted ? Theme.red : Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
    }
    // A device row: the default one checked; a click makes it the default
    component Device: PanelRow {
        required property var modelData
        required property int index
        property bool output: true
        readonly property bool isDefault: (output ? root.sink : root.source) === modelData
        // A blank icon still takes the space, so the names stay aligned
        icon: isDefault ? "󰄬" : " "
        text: Lists.audioDeviceName(modelData)
        onClicked: root.makeDefault(modelData, output)
    }

    Layout.fillWidth: true
    spacing: 2

    // ── Output ──
    Caption {
        text: "Saída"
    }
    Level {
        visible: root.outputLevel && root.live(root.sink)
        node: root.sink
    }
    Caption {
        visible: root.m.sinks.length === 0
        text: "Sem saída de áudio"
    }
    Repeater {
        model: root.m.sinks
        Device {
            output: true
            keyFocus: root.keyOn("sink", index)
        }
    }

    // ── Microphone ──
    Caption {
        text: "Microfone"
    }
    Level {
        visible: root.live(root.source)
        node: root.source
        onIcon: String.fromCodePoint(0xF036C)    // nf-md-microphone
        offIcon: String.fromCodePoint(0xF036D)   // nf-md-microphone_off
        muteFocus: root.keyOn("micMute")
    }
    Caption {
        visible: root.m.sources.length === 0
        text: "Sem microfone"
    }
    Repeater {
        model: root.m.sources
        Device {
            output: false
            keyFocus: root.keyOn("source", index)
        }
    }

    // ── Apps playing sound ──
    Caption {
        text: "Apps"
    }
    Caption {
        visible: root.m.streams.length === 0
        text: "Nenhum app tocando som"
    }
    Flickable {
        id: flick
        visible: root.m.streams.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(apps.implicitHeight, root.maxListHeight)
        contentWidth: width
        contentHeight: apps.implicitHeight
        interactive: apps.implicitHeight > root.maxListHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: apps
            width: flick.width
            spacing: 4

            Repeater {
                model: root.m.streams

                ColumnLayout {
                    id: app
                    required property var modelData
                    required property int index
                    readonly property string iconName: Lists.streamIcon(modelData)
                    readonly property string iconPath: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""

                    Layout.fillWidth: true
                    spacing: 0

                    readonly property bool keyed: root.keyOn("stream", index)
                    onKeyedChanged: {
                        if (keyed) {
                            if (y < flick.contentY)
                                flick.contentY = y
                            else if (y + height > flick.contentY + flick.height)
                                flick.contentY = y + height - flick.height
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        spacing: 8

                        // The theme's icon for the app, else a generic one
                        Image {
                            visible: app.iconPath !== ""
                            source: app.iconPath
                            sourceSize.width: 16
                            sourceSize.height: 16
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                        }
                        Text {
                            visible: app.iconPath === ""
                            text: String.fromCodePoint(0xF075A)   // nf-md-music_note
                            textFormat: Text.PlainText
                            color: Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Lists.streamName(app.modelData)
                            textFormat: Text.PlainText
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                        }
                    }
                    Level {
                        node: app.modelData
                        muteFocus: app.keyed
                    }
                }
            }
        }
    }
    Caption {
        visible: root.m.hiddenStreams > 0
        text: `e mais ${root.m.hiddenStreams}`
    }
}
