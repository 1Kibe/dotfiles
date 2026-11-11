import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The warning before the idle lock (hypridle, 4 min 30 s): every monitor
// darkens and a pill counts down the seconds to the lock (the number comes
// from hypridle.conf, "dim 30"), with a thin line that shrinks to nothing.
// Only visual: it never takes the keyboard or the mouse (an empty input
// region), so any key or move reaches the session, hypridle sees the
// activity and calls undim. Gone as soon as the screen locks.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property var modelData
        readonly property bool shown: LockState.dimmed && !LockState.wanted
        // A known deadline: count down; else the text has no number
        readonly property bool counting: LockState.dimDeadline > 0
        property int remaining: 0

        screen: modelData
        visible: shown || fade.running
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.clear
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-dim"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // No input at all: clicks and moves go to whatever is below
        mask: Region {}

        // Whole seconds left, from the deadline (never by adding up ticks, so
        // a late tick does not drift)
        function update() {
            remaining = counting ? Math.max(0, Math.ceil((LockState.dimDeadline - Date.now()) / 1000)) : 0
        }

        // On show: the line starts at the share of time still left and runs
        // down to zero by the deadline
        onShownChanged: {
            update()
            line.stop()
            if (shown && counting) {
                const left = Math.max(0, LockState.dimDeadline - Date.now())
                line.from = Math.min(1, left / (LockState.dimSeconds * 1000))
                line.duration = left
                line.start()
            }
        }

        Timer {
            interval: 200
            repeat: true
            running: root.shown && root.counting
            onTriggered: root.update()
        }

        Rectangle {
            id: veil
            anchors.fill: parent
            color: Theme.idleVeil
            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { id: fade; duration: Theme.animNormal * 2; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                // Under the bar, or from the top with the bar on the bottom edge
                anchors.topMargin: Theme.barAtBottom ? Theme.idlePillGap : Theme.barHeight + Theme.idlePillGap
                width: content.implicitWidth + 32
                height: Theme.idlePillHeight
                radius: height / 2
                color: Theme.lockPillFill
                clip: true

                Row {
                    id: content
                    anchors.centerIn: parent

                    Text {
                        text: root.counting ? "󰌾  A tela trava em " : "󰌾  A tela vai travar"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.idleTextSize
                    }

                    // The number: a fixed width (as wide as the first one) so
                    // the pill does not jump; each new number slides in
                    Item {
                        visible: root.counting
                        width: widest.width
                        height: number.height

                        TextMetrics {
                            id: widest
                            font: number.font
                            text: "0".repeat(String(LockState.dimSeconds).length)
                        }

                        Text {
                            id: number
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.remaining
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.idleTextSize
                            onTextChanged: tick.restart()

                            ParallelAnimation {
                                id: tick
                                NumberAnimation {
                                    target: number
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: number
                                    property: "anchors.verticalCenterOffset"
                                    from: -Theme.idleNumberShift
                                    to: 0
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Text {
                        text: root.counting ? " s · mexa para cancelar" : " · mexa para cancelar"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.idleTextSize
                    }
                }

                // Time left: full at the start, nothing at the lock
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.idleLineGap
                    anchors.leftMargin: pill.radius
                    visible: root.counting
                    height: Theme.idleLineHeight
                    radius: height / 2
                    color: Theme.idleLine
                    property real share: 1
                    width: (pill.width - 2 * pill.radius) * share

                    NumberAnimation on share {
                        id: line
                        running: false
                        to: 0
                    }
                }
            }
        }
    }
}
