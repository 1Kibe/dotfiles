import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.bar
import "lists.js" as Lists

// The mixer, in the control center's mixer section (under the volume
// slider) and in the bar's volume panel, with the sections' common parts
// (ListHeader, ListBlock, ListRow): the output devices, the microphone
// (its level and mute, and its devices) and one row per app playing sound
// (icon, name, level, mute), the apps scrolling inside past
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

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF057E)   // nf-md-volume_high
        title: "Mixer"
        detail: root.m.streams.length === 0 ? "Nenhum app tocando"
              : root.m.streams.length === 1 ? "1 app tocando" : `${root.m.streams.length + root.m.hiddenStreams} apps tocando`
    }

    // ── Output: in the bar's panel its own level on top; the devices, the
    // default one "em uso", a click on another makes it the default ──
    ListHeader {
        title: "Saídas"
    }
    ListBlock {
        ListRow {
            visible: root.outputLevel && root.live(root.sink)
            fillTrailing: true
            textWidth: 0
            icon: String.fromCodePoint(0xF04C3)   // nf-md-speaker

            LevelRow {
                Layout.fillWidth: true
                node: root.sink
                ok: root.live(root.sink)
                onMuteClicked: root.toggleMute(root.sink)
                onMoved: v => root.setVolume(root.sink, v)
            }
        }
        ListRow {
            visible: root.m.sinks.length === 0
            text: "Sem saída de áudio"
            textColor: Theme.gray
        }
        Repeater {
            model: root.m.sinks

            ListRow {
                required property var modelData
                required property int index
                readonly property bool isDefault: root.sink === modelData
                divider: index > 0 || (root.outputLevel && root.live(root.sink))
                clickable: !isDefault
                icon: isDefault ? String.fromCodePoint(0xF012C) : " "   // nf-md-check; a blank keeps the names aligned
                iconColor: Theme.accentLight
                text: Lists.audioDeviceName(modelData) || "Aparelho sem nome"
                detail: isDefault ? "em uso" : "Usar"
                keyFocus: root.keyOn("sink", index)
                onClicked: root.makeDefault(modelData, true)
            }
        }
    }

    // ── Microphone: its level and mute, then its devices ──
    ListHeader {
        title: "Microfone"
    }
    ListBlock {
        ListRow {
            visible: root.live(root.source)
            fillTrailing: true
            textWidth: 0
            icon: String.fromCodePoint(0xF036C)   // nf-md-microphone

            LevelRow {
                Layout.fillWidth: true
                node: root.source
                ok: root.live(root.source)
                onIcon: String.fromCodePoint(0xF036C)    // nf-md-microphone
                offIcon: String.fromCodePoint(0xF036D)   // nf-md-microphone_off
                muteFocus: root.keyOn("micMute")
                onMuteClicked: root.toggleMute(root.source)
                onMoved: v => root.setVolume(root.source, v)
            }
        }
        ListRow {
            visible: root.m.sources.length === 0
            text: "Sem microfone"
            textColor: Theme.gray
        }
        Repeater {
            model: root.m.sources

            ListRow {
                required property var modelData
                required property int index
                readonly property bool isDefault: root.source === modelData
                divider: index > 0 || root.live(root.source)
                clickable: !isDefault
                icon: isDefault ? String.fromCodePoint(0xF012C) : " "   // nf-md-check
                iconColor: Theme.accentLight
                text: Lists.audioDeviceName(modelData) || "Aparelho sem nome"
                detail: isDefault ? "em uso" : "Usar"
                keyFocus: root.keyOn("source", index)
                onClicked: root.makeDefault(modelData, false)
            }
        }
    }

    // ── Apps playing sound: one row each (icon, name, level, mute) ──
    ListHeader {
        title: "Apps"
        detail: root.m.streams.length > 0 ? String(root.m.streams.length + root.m.hiddenStreams) : ""
    }
    ListBlock {
        id: appsBlock
        maxHeight: root.maxListHeight

        ListRow {
            visible: root.m.streams.length === 0
            text: "Nenhum app tocando som"
            textColor: Theme.gray
        }
        Repeater {
            model: root.m.streams

            ListRow {
                id: app
                required property var modelData
                required property int index
                readonly property string iconName: Lists.streamIcon(modelData)
                readonly property bool keyed: root.keyOn("stream", index)

                divider: index > 0
                fillTrailing: true
                textWidth: Math.round(root.width * 0.3)
                // The theme's icon for the app, else a generic one
                image: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""
                icon: String.fromCodePoint(0xF075A)   // nf-md-music_note
                text: Lists.streamName(modelData) || "App sem nome"
                onKeyedChanged: {
                    if (keyed)
                        appsBlock.reveal(app)
                }

                LevelRow {
                    Layout.fillWidth: true
                    node: app.modelData
                    ok: root.live(app.modelData)
                    muteFocus: app.keyed
                    onMuteClicked: root.toggleMute(app.modelData)
                    onMoved: v => root.setVolume(app.modelData, v)
                }
            }
        }
        ListRow {
            visible: root.m.hiddenStreams > 0
            divider: true
            text: `e mais ${root.m.hiddenStreams}`
            textColor: Theme.gray
        }
    }
}
