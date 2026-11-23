import QtQuick
import Quickshell
import qs.theme

// The preview of a minimized window, next to the open strip (PreviewFace:
// "App · title" and the picture). Fades in with a short scale (reduce
// motion: the fade only). Shown, going to another row: the card slides to
// it and the window crossfades, the old one out and the new one in at once
// (reduce motion: the crossfade only). Two faces, never more: a third
// window while they cross takes the one going out.
Rectangle {
    id: root

    // The entry ({ cls, title, shot, ... }); null: hidden
    property var entry: null
    // Shown: a new entry is a change of row (the card slides, the faces
    // cross); set a turn after it shows, cleared when it hides
    property bool live: false
    readonly property Item front: aFront ? faceA : faceB
    readonly property Item back: aFront ? faceB : faceA
    property bool aFront: true
    // The face coming in, waiting for its picture to load
    property Item waiting: null

    width: Theme.previewWidth
    height: Theme.previewHeight
    radius: Theme.radius
    color: Theme.stripFill
    clip: true
    opacity: entry ? 1 : 0
    scale: entry || Theme.reduceMotion ? 1 : Theme.previewScale
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: Theme.dur(Theme.animFast) }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.dur(Theme.animFast) }
    }
    Behavior on y {
        enabled: root.live && !Theme.reduceMotion
        NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
    }

    onEntryChanged: {
        if (!entry) {
            // Hiding: the face stays while the card fades
            live = false
            return
        }
        if (!live) {
            // Showing: the window at once, the card fades in
            fadeIn.stop()
            fadeOut.stop()
            waiting = null
            front.entry = entry
            front.opacity = 1
            back.opacity = 0
            back.entry = null
            Qt.callLater(() => {
                if (root.entry)
                    root.live = true
            })
            return
        }
        // The same window (its title changed): no crossing
        if (front.entry && front.entry.address === entry.address) {
            front.entry = entry
            return
        }
        swap()
    }
    function swap() {
        // The one coming in had not started yet: it takes the newer window
        // (the old one stays until then)
        if (waiting) {
            const w = waiting
            w.entry = entry
            // (its ready may have crossed already, while the entry changed)
            if (waiting === w && w.ready)
                cross()
            return
        }
        fadeIn.stop()
        fadeOut.stop()
        const going = front, coming = back
        coming.opacity = 0
        coming.entry = entry
        aFront = !aFront
        waiting = coming
        fadeOut.target = going
        if (coming.ready)
            cross()
    }
    // Both at once, once the new one has something to show
    function cross() {
        const coming = waiting
        waiting = null
        if (!coming)
            return
        fadeOut.from = fadeOut.target.opacity
        fadeOut.start()
        fadeIn.target = coming
        fadeIn.start()
    }
    Connections {
        target: faceA
        function onReadyChanged() {
            if (root.waiting === faceA && faceA.ready)
                root.cross()
        }
    }
    Connections {
        target: faceB
        function onReadyChanged() {
            if (root.waiting === faceB && faceB.ready)
                root.cross()
        }
    }
    NumberAnimation {
        id: fadeIn
        property: "opacity"
        to: 1
        duration: Theme.dur(Theme.animFast)
    }
    NumberAnimation {
        id: fadeOut
        property: "opacity"
        to: 0
        duration: Theme.dur(Theme.animFast)
        // Gone: its picture is let go
        onFinished: {
            if (target && target !== root.front)
                target.entry = null
        }
    }

    PreviewFace {
        id: faceA
        anchors.fill: parent
    }
    PreviewFace {
        id: faceB
        anchors.fill: parent
        opacity: 0
    }
}
