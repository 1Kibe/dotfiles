import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The frozen frames of a change of profile or theme (state/SwapState): one
// overlay per monitor that takes no input and no keyboard. While SwapState
// freezes, the overlay is up but clear; after a few frames (so it is clear
// on screen) it takes one picture of its monitor, kept in memory only
// (ScreencopyView, live off, no cursor), and shows it once it is in, over
// everything. The change happens underneath; then the picture leaves:
// fade (it fades out), slide (it goes out to the left), curtain (its two
// halves run to the edges) or circle (a growing circle shows the new screen,
// from the cursor on the focused monitor or from the middle). The picture
// is dropped when SwapState ends, the lock comes in or the monitor leaves.
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                readonly property string name: modelData.name
                readonly property string phase: SwapState.phase
                readonly property bool wanted: phase !== ""

                screen: modelData
                visible: wanted
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: Theme.clear
                mask: Region {}
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-swap"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Registered only once the window exists (none under a
                // platform with no layer shell: the change happens directly)
                Component.onCompleted: SwapState.addFrame(name, win)
                Component.onDestruction: SwapState.removeFrame(name, win)

                // The picture is taken once this overlay is clear on screen
                property bool armed: false
                onWantedChanged: {
                    armed = false
                    progress = 0
                    if (wanted)
                        arm.restart()
                    else
                        arm.stop()
                }
                Timer {
                    id: arm
                    interval: 100
                    onTriggered: win.armed = true
                }
                readonly property bool hasFrame: frozen.hasContent && armed
                onHasFrameChanged: {
                    if (hasFrame)
                        SwapState.frameReady(name)
                }

                // 0 → 1 while the picture leaves
                property real progress: 0
                readonly property bool revealing: phase === "reveal"
                onRevealingChanged: {
                    if (revealing && hasFrame)
                        leave.restart()
                    else if (revealing)
                        SwapState.frameRevealed(name)
                }
                NumberAnimation {
                    id: leave
                    target: win
                    property: "progress"
                    from: 0
                    to: 1
                    duration: Theme.dur(Theme.swapDuration)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                    onFinished: SwapState.frameRevealed(win.name)
                }

                ScreencopyView {
                    id: frozen
                    width: win.width
                    height: win.height
                    captureSource: win.wanted && win.armed ? win.modelData : null
                    live: false
                    paintCursor: false
                }
                // Nothing shows until the picture is in; then the picture
                // through the chosen effect
                SwapEffect {
                    anchors.fill: parent
                    visible: win.hasFrame && (win.phase === "cover" || win.phase === "reveal")
                    source: frozen
                    kind: SwapState.kind
                    progress: win.progress
                    readonly property bool here: SwapState.originScreen === win.name
                    ox: here ? SwapState.originX : -1
                    oy: here ? SwapState.originY : -1
                }
            }
        }
    }
}
