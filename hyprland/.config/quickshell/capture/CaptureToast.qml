import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Small notice at the top middle of the focused monitor ("Copiado ·
// salvo", "Vídeo salvo", failures), with an optional folder button. Fades
// in, goes away after about 3 s (stays while the mouse is on it). Lives
// here until there is a notifications module.
PanelWindow {
    id: root

    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === CaptureState.focusName) ?? Quickshell.screens[0]
    visible: shown || fade.running
    anchors.top: true
    margins.top: Theme.barHeight + Theme.gap
    implicitWidth: pill.width
    implicitHeight: pill.height
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture-toast"

    Connections {
        target: CaptureState
        function onToastSerialChanged() {
            root.shown = true
            pill.opacity = 1
            timer.restart()
        }
    }

    Timer {
        id: timer
        interval: 3000
        onTriggered: {
            if (hover.hovered)
                restart()
            else
                root.shown = false
        }
    }

    Rectangle {
        id: pill
        width: row.implicitWidth + 24
        height: Theme.captureButtonHeight + 10
        radius: height / 2
        color: Theme.stripFill
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { id: fade; duration: root.shown ? Theme.animNormal : Theme.animFast }
        }

        HoverHandler {
            id: hover
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: CaptureState.toastIcon
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 1
            }
            Text {
                text: CaptureState.toastText
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            CaptureButton {
                visible: CaptureState.toastFolder !== ""
                icon: "󰉋"
                hint: "Abrir a pasta"
                onPressed: {
                    Quickshell.execDetached(["xdg-open", CaptureState.toastFolder])
                    root.shown = false
                }
            }
        }
    }
}
