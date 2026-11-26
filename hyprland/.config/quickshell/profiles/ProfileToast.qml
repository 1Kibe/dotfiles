import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.state
import "../settings/ui"
import "../theme/seal.js" as Seal

// Super+Shift+T's notice (state/CarouselState): a pill at the top middle of
// the focused monitor, as the capture's notice, with the profile's seal, its
// name and "N de M" (or a text alone: "Só há um perfil"). About 2 s; the
// same notice again starts over. Shown only once the change is over.
PanelWindow {
    id: root

    property bool shown: false
    readonly property var p: CarouselState.toastProfile
    readonly property var colors: p !== null ? ProfileStore.colorsOf(p) : null
    readonly property var pair: colors ? Seal.sealColors(colors.named, String(colors.accent)) : ["red", "blue"]

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: shown || fade.running
    onVisibleChanged: ShellState.setOverlay("profileToast", visible)
    anchors.top: true
    margins.top: Theme.barAtBottom ? Theme.gap : Theme.barHeight + Theme.gap
    implicitWidth: pill.width
    implicitHeight: pill.height
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-profiles-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: CarouselState
        function onToastSerialChanged() {
            root.shown = true
            timer.restart()
        }
    }
    Timer {
        id: timer
        interval: 2000
        onTriggered: root.shown = false
    }

    Rectangle {
        id: pill
        width: row.implicitWidth + 24
        height: Theme.captureButtonHeight + 10
        radius: height / 2
        color: Theme.stripFill
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { id: fade; duration: root.shown ? Theme.dur(Theme.animNormal) : Theme.dur(Theme.animFast) }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8
            ColorSeal {
                visible: root.colors !== null
                Layout.preferredWidth: Theme.captureButtonHeight - 8
                Layout.preferredHeight: Theme.captureButtonHeight - 8
                outline: root.colors ? root.colors.roles.bgDeep : "transparent"
                thin: root.colors ? root.colors.roles.bg2 : "transparent"
                accent: root.colors ? root.colors.accent : "transparent"
                colorA: root.colors ? root.colors.named[root.pair[0]] : "transparent"
                colorB: root.colors ? root.colors.named[root.pair[1]] : "transparent"
            }
            Text {
                visible: root.p !== null
                text: root.p !== null ? root.p.nome : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.maximumWidth: 320
                color: Theme.text
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize
            }
            Text {
                text: CarouselState.toastText
                textFormat: Text.PlainText
                color: root.p !== null ? Theme.fg4 : Theme.text
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - (root.p !== null ? 1 : 0)
            }
        }
    }
}
