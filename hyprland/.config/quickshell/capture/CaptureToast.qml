import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Small notice at the top middle of the focused monitor ("Copiado ·
// salvo", "Vídeo salvo", failures), with an optional folder button (and a
// play button for a saved video, which opens in mpv). Fades
// in, goes away after about 3 s (stays while the mouse is on it). Lives
// here until there is a notifications module.
PanelWindow {
    id: root

    // On while the notice is up; the window stays mapped while the fade runs
    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === CaptureState.focusName) ?? Quickshell.screens[0]
    visible: shown || fade.running
    anchors.top: true
    // Just under the bar, or at the top with the bar on the bottom edge
    margins.top: Theme.barAtBottom ? Theme.gap : Theme.barHeight + Theme.gap
    implicitWidth: pill.width
    implicitHeight: pill.height
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture-toast"

    // CaptureState.toast() bumps toastSerial, so the same text twice in a row
    // still shows again and restarts the 3 s
    Connections {
        target: CaptureState
        function onToastSerialChanged() {
            root.shown = true
            pill.opacity = 1
            timer.restart()
        }
    }

    // Never hides under the mouse: while hovered it checks again every 3 s
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
        // 12 px on each side of the row; 5 px above and below a button
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
            // Only on "Vídeo salvo"; openVideo checks the path again before mpv
            CaptureButton {
                visible: CaptureState.toastVideo !== ""
                icon: "󰐊"
                hint: "Abrir o vídeo"
                onPressed: {
                    CaptureState.openVideo(CaptureState.toastVideo)
                    root.shown = false
                }
            }
            // The folder the file went to, in the default file manager
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
