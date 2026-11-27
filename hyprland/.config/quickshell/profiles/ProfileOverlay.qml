import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Super+T: the profiles as posters (state/CarouselState). Over every
// monitor the desktop goes dark and blurred (the layer's blur, rules.lua);
// on the monitor it opened on, the cards: the picked one in the middle,
// larger and lighter, its neighbors in a fan, smaller and darker, fading out
// at the ends; under it the name and "perfil ativo · N / M". More than six:
// a grid over the whole screen. Arrows, the wheel, a click and 1 to 9 pick;
// Enter (or a click on the picked one) applies; Esc closes. No frame, no
// tick, no header, no row of keys. Reduce motion: the fade only.
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                readonly property bool here: CarouselState.openOn === modelData.name
                readonly property bool shown: CarouselState.open

                screen: modelData
                // No surface while closed (nothing of the shell stays over a
                // full-screen game or video); the cards and their pictures
                // stay loaded, so opening only maps it again
                readonly property bool up: shown || fade.running
                visible: up
                // (registered while up, the fade out too)
                onUpChanged: CarouselState.shown = up
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: Theme.clear
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-profiles"
                WlrLayershell.keyboardFocus: shown && here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                Item {
                    id: content
                    anchors.fill: parent
                    opacity: win.shown ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            id: fade
                            // (closing before a change: at once, the frozen
                            // frame must not hold it)
                            duration: CarouselState.instant && !win.shown ? 0 : Theme.dur(Theme.animNormal)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: win.shown ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // The dark veil (the blur behind is the layer's)
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.alpha(Theme.bgDeep, Theme.profileDim)
                    }
                    // A click outside the cards closes
                    MouseArea {
                        anchors.fill: parent
                        onClicked: CarouselState.close()
                    }

                    CarouselView {
                        id: cards
                        anchors.fill: parent
                        visible: win.here
                        shown: win.shown
                        keys.focus: win.here && win.shown
                    }
                }
            }
        }
    }
}
