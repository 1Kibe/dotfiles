import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.bar

// The level of one sound node in the mixer: the slider (0..100%), the
// percent and the mute button. It only draws: the mixer (AudioMixer) says
// whether the node is ready and writes the volume and the mute.
RowLayout {
    id: root

    required property var node
    // The node tracked and ready (AudioMixer.live)
    property bool ok: false
    property string onIcon: String.fromCodePoint(0xF057E)     // nf-md-volume_high
    property string offIcon: String.fromCodePoint(0xF075F)    // nf-md-volume_off
    property bool muteFocus: false
    readonly property bool muted: ok && node.audio.muted
    signal muteClicked()
    signal moved(real value)

    spacing: 6

    PanelSlider {
        Layout.fillWidth: true
        Layout.preferredWidth: 60
        enabled: root.ok
        value: root.ok ? Math.min(1, root.node.audio.volume) : 0
        muted: root.muted
        onMoved: v => root.moved(v)
    }
    // Fixed width so the slider does not jump as the digits change
    Text {
        Layout.preferredWidth: 32
        horizontalAlignment: Text.AlignRight
        text: root.ok ? `${Math.round(root.node.audio.volume * 100)}%` : ""
        textFormat: Text.PlainText
        color: root.muted ? Theme.red : Theme.fg4
        font.family: Theme.monoFont
        font.pointSize: Theme.fontSizeSmall
    }
    BarItem {
        text: root.muted || !root.ok ? root.offIcon : root.onIcon
        textColor: !root.ok ? Theme.gray : root.muted ? Theme.red : Theme.fg4
        tooltip: root.muted ? "Ativar o som" : "Silenciar"
        keyFocus: root.muteFocus
        onClicked: root.muteClicked()
    }
}
