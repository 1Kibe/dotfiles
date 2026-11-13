import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import "ui"

// While something is being tried (the screens, the keyboard layout), a
// strip on top of every screen that is on: the question with the seconds
// left, and Manter / Voltar. No answer: it goes back by itself (a timer
// outside the shell, armed by whoever shows the strip). It is the way out
// for someone who cannot see the screen right or cannot type: one strip for
// every preview. The first ~400 ms take no click or key (a click meant for
// the page must not land on Manter), a held key never counts, and neither
// button starts focused. On the focused screen, Enter keeps and Esc goes
// back; both buttons work with the mouse alone.
Variants {
    id: strip

    property bool shown: false
    property string question: ""
    property string namespace: "quickshell-keep"
    signal keep()
    signal back()

    model: Quickshell.screens

    PanelWindow {
        id: root

        required property var modelData
        readonly property bool shown: strip.shown
        readonly property bool focusedHere: Hyprland.focusedMonitor !== null
                                            && Hyprland.focusedMonitor.name === modelData.name
        // Clicks and keys count only after a short wait
        property bool armed: false
        onShownChanged: {
            armed = false
            if (shown)
                armTimer.restart()
        }
        Timer {
            id: armTimer
            interval: 400
            onTriggered: root.armed = true
        }

        screen: modelData
        visible: shown
        anchors.top: true
        margins.top: 48
        implicitWidth: strip.implicitWidth
        implicitHeight: strip.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        color: Theme.clear
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: strip.namespace
        WlrLayershell.keyboardFocus: shown && focusedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: strip
            implicitWidth: row.implicitWidth + 32
            implicitHeight: row.implicitHeight + 20
            radius: Theme.radius
            color: Theme.bg
            border.width: 1
            border.color: Theme.bg2
            focus: true

            Keys.onPressed: event => {
                event.accepted = true
                if (event.isAutoRepeat || !root.armed)
                    return
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    strip.keep()
                else if (event.key === Qt.Key_Escape)
                    strip.back()
            }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: strip.question
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize
                }
                Button {
                    text: "Manter"
                    icon: "󰄬"
                    activeFocusOnTab: false
                    onClicked: if (root.armed) strip.keep()
                }
                Button {
                    text: "Voltar"
                    icon: "󰕌"
                    activeFocusOnTab: false
                    onClicked: if (root.armed) strip.back()
                }
            }
        }
    }
}
