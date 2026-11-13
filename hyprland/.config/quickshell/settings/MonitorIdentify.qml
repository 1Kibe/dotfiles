import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Identificar (Configurações → Monitores): for a moment, each screen that
// is on shows its number in the arrangement, big, in the middle. Only the
// number: never the screen's name or description. Takes no input.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property var modelData
        // Its position in the areas (state/AreasState), as on the page
        readonly property int number: {
            const on = MonitorsApply.screens.filter(s => s.enabled).map(s => s.name)
            const k = AreasState.place(AreasState.saved, on)[modelData.name]
            return on.includes(modelData.name) && k !== undefined ? k : 0
        }

        screen: modelData
        visible: MonitorsApply.identifying && number > 0
        implicitWidth: 180
        implicitHeight: 180
        exclusionMode: ExclusionMode.Ignore
        color: Theme.clear
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-monitor-identify"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius * 2
            color: Theme.alpha(Theme.bg, 0.92)
            border.width: 2
            border.color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: String(root.number)
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.fontPanels
                font.pixelSize: 96
                font.weight: Font.DemiBold
            }
        }
    }
}
