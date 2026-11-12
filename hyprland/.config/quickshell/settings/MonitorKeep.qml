import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state
import "ui"

// While an arrangement is being tried (state/MonitorsApply), a strip on top
// of every screen that is on: "Manter estas telas?", the seconds left, and
// Manter / Voltar. No answer: it goes back by itself (the timer outside the
// shell). The first ~400 ms take no click or key (a click meant for the page
// must not land on Manter), a held key never counts, and neither button
// starts focused. On the focused screen, Enter keeps and Esc goes back.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property var modelData
        readonly property bool shown: MonitorsApply.pending
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
        WlrLayershell.namespace: "quickshell-monitor-keep"
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
                    MonitorsApply.keep()
                else if (event.key === Qt.Key_Escape)
                    MonitorsApply.revert()
            }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: `Manter estas telas? Volta em ${MonitorsApply.left} s`
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize
                }
                Button {
                    text: "Manter"
                    icon: "󰄬"
                    activeFocusOnTab: false
                    onClicked: if (root.armed) MonitorsApply.keep()
                }
                Button {
                    text: "Voltar"
                    icon: "󰕌"
                    activeFocusOnTab: false
                    onClicked: if (root.armed) MonitorsApply.revert()
                }
            }
        }
    }
}
