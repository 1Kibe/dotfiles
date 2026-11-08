import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Delay of the capture: a circle in the middle of the focused monitor,
// 3 → 2 → 1, each number with a short fade and scale. Esc cancels. It is
// gone before the screen freezes, so it never shows up in the picture.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === CaptureState.focusName) ?? Quickshell.screens[0]
    visible: CaptureState.open && CaptureState.phase === "countdown"
    implicitWidth: Theme.countdownSize
    implicitHeight: Theme.countdownSize
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture-countdown"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.stripFill
        border.width: 2
        border.color: Theme.accentLight

        Text {
            id: number
            anchors.centerIn: parent
            text: CaptureState.countdownLeft
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 38
            font.bold: true

            onTextChanged: pop.restart()
            ParallelAnimation {
                id: pop
                NumberAnimation { target: number; property: "opacity"; from: 0.2; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                NumberAnimation { target: number; property: "scale"; from: 1.3; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }
        }
    }

    Item {
        focus: true
        Keys.onEscapePressed: CaptureState.cancelCountdown()
    }
}
