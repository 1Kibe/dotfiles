import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// A minimized window's picture flying (MinimizeState.flights): from its
// place to the middle of its screen's wire, shrinking to
// Theme.minimizeFlyScale and fading in the last third, and back the other
// way, growing and appearing, while the window itself is hidden or still
// invisible (Hyprland moves it at once). One window per screen over
// everything, only while a picture flies on it, taking neither the mouse
// nor the keyboard. Reduce motion: the picture only fades where the window
// is. With no picture (it could not be taken), the app's icon on a card.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string name: modelData.name
        readonly property var mine: MinimizeState.flights.filter(f => f.screen === win.name)

        screen: modelData
        visible: mine.length > 0
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
        WlrLayershell.namespace: "quickshell-minimize-flight"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // The flights by id: one already flying keeps its animation when
        // another starts or ends
        ListModel {
            id: flying
        }
        onMineChanged: {
            const ids = mine.map(f => f.id)
            for (let i = flying.count - 1; i >= 0; i--) {
                if (!ids.includes(flying.get(i).fid))
                    flying.remove(i)
            }
            for (const f of mine) {
                let has = false
                for (let i = 0; i < flying.count; i++)
                    if (flying.get(i).fid === f.id)
                        has = true
                if (!has)
                    flying.append({ fid: f.id })
            }
        }

        Repeater {
            model: flying

            Item {
                id: pic
                required property int fid
                readonly property var f: win.mine.find(x => x.id === fid) ?? null
                // 0 at the start, 1 at the end of the way
                property real t: 0
                readonly property real k: Theme.reduceMotion ? 0 : t
                visible: f !== null
                x: f ? f.from.x + (f.to.x - f.from.x) * k : 0
                y: f ? f.from.y + (f.to.y - f.from.y) * k : 0
                width: f ? f.from.w + (f.to.w - f.from.w) * k : 0
                height: f ? f.from.h + (f.to.h - f.from.h) * k : 0
                // Out: seen until the last third, then fading; in: the
                // other way. Reduce motion: the whole way fading
                opacity: !f ? 0 : Theme.reduceMotion ? (f.dir === "out" ? 1 - t : t)
                    : f.dir === "out" ? Math.min(1, 3 * (1 - t)) : Math.min(1, 3 * t)

                NumberAnimation on t {
                    from: 0
                    to: 1
                    duration: Theme.dur(Theme.minimizeFly)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                    onFinished: MinimizeState.flightDone(pic.fid)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.bg1
                    clip: true

                    Image {
                        id: shot
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: pic.f && pic.f.shot !== "" ? "file://" + pic.f.shot : ""
                        fillMode: Image.Stretch
                        asynchronous: false
                        cache: false
                    }
                    Image {
                        anchors.centerIn: parent
                        visible: shot.status !== Image.Ready && source !== ""
                        source: pic.f ? AppIcons.icon(pic.f.cls) : ""
                        width: Math.min(parent.width, parent.height) / 3
                        height: width
                        sourceSize.width: Theme.previewIcon
                        sourceSize.height: Theme.previewIcon
                    }
                }
            }
        }
    }
}
