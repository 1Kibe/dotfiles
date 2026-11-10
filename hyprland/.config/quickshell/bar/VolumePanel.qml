import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.theme

// Volume panel: output and microphone, each with mute, a slider and the
// list of devices (the default one checked; click to make it the default).
AttachedPanel {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // Hardware devices only: nodes with audio controls that are not app
    // streams (a browser tab, a player). Split into outputs and inputs.
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio !== null && !n.isStream)
    readonly property var sinks: nodes.filter(n => n.isSink)
    readonly property var sources: nodes.filter(n => !n.isSink)

    // The friendliest name the node has; the raw node name as a last resort
    function label(node) {
        return node.description || node.nickname || node.name
    }

    panelWidth: 320

    // Volume and mute are only live on tracked nodes
    PwObjectTracker {
        objects: root.nodes
    }

    // One block: title with mute, slider with percent, device list
    component AudioBlock: ColumnLayout {
        id: block

        required property string title
        required property var node          // default device
        required property var devices
        required property string emptyText
        required property string mutedIcon
        required property string onIcon
        required property bool isOutput

        // No default device, or not bound yet: hide the mute button and the
        // slider rather than show a fake 0%
        readonly property bool ok: node !== null && node.ready && node.audio !== null
        readonly property bool muted: ok && node.audio.muted

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 6
            implicitHeight: 34

            Text {
                Layout.fillWidth: true
                text: block.title
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
                font.bold: true
            }
            BarItem {
                visible: block.ok
                text: block.muted ? block.mutedIcon : block.onIcon
                textColor: block.muted ? Theme.red : Theme.text
                tooltip: block.muted ? "Ativar o som" : "Silenciar"
                onClicked: block.node.audio.muted = !block.node.audio.muted
            }
        }

        RowLayout {
            visible: block.ok
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 10

            // Writes straight to PipeWire on every move; the value comes
            // back through the binding, so outside changes show up too
            PanelSlider {
                Layout.fillWidth: true
                value: block.ok ? block.node.audio.volume : 0
                muted: block.muted
                onMoved: v => block.node.audio.volume = v
            }
            // Fixed width so the slider does not jump as the digits change
            Text {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: block.ok ? `${Math.round(block.node.audio.volume * 100)}%` : ""
                color: block.muted ? Theme.red : Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
        }

        Text {
            visible: block.devices.length === 0
            Layout.leftMargin: 12
            Layout.bottomMargin: 4
            text: block.emptyText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }

        Repeater {
            model: block.devices

            PanelRow {
                required property var modelData
                readonly property bool isDefault: block.node !== null && modelData.id === block.node.id

                // A blank icon still takes the space, so the names stay aligned
                icon: isDefault ? "󰄬" : " "
                text: root.label(modelData)
                // Asks the session manager to switch the default; sink and
                // source above follow it, which moves the check mark
                onClicked: {
                    if (block.isOutput)
                        Pipewire.preferredDefaultAudioSink = modelData
                    else
                        Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }

    AudioBlock {
        title: "Saída"
        node: root.sink
        devices: root.sinks
        emptyText: "Sem saída de áudio"
        mutedIcon: "󰝟"
        onIcon: "󰕾"
        isOutput: true
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.bg2
    }

    AudioBlock {
        title: "Microfone"
        node: root.source
        devices: root.sources
        emptyText: "Sem microfone"
        mutedIcon: "󰍭"
        onIcon: "󰍬"
        isOutput: false
    }
}
