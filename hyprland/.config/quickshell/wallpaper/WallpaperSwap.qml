import QtQuick
import qs.theme

// A full picture that changes smoothly: the desktop wallpaper, and later a
// theme profile's. The new picture (`source`, a file URL, with its `fill`)
// loads in the background and comes in only once it is ready, fading in over
// the old one with a slight zoom out (Theme.wallpaperFade, the standard curve);
// the old one stays whole underneath until the end, so there is never a frame
// with no picture, however slow the new one is to load. A new fill alone
// changes the same way. An empty source fades the picture out (the plain color
// behind shows). A change asked during a swap waits for its end, so the picture
// underneath is never replaced while it shows. A new picture that cannot be
// loaded is logged and dropped: the old one stays. Reduce motion: the fade
// only. Speed 0: at once. One swap at a time, never a running animation.
Item {
    id: root

    property string source
    // "fill" | "fit" | "center" | "tile"
    property string fill: "fill"

    // The layer in front (0 or 1) and whether a picture shows
    property int front: 0
    property bool hasPicture: false
    readonly property bool swapping: swap.running
    readonly property string key: source === "" ? "" : `${source}|${fill}`
    property bool pending: false

    function pane(n) {
        return n === 0 ? a : b
    }

    onKeyChanged: load()
    Component.onCompleted: load()

    function load() {
        if (swap.running || fadeOut.running) {
            pending = true
            return
        }
        pending = false
        if (key === "") {
            if (hasPicture)
                fadeOut.restart()
            return
        }
        if (hasPicture && pane(front).key === key && pane(front).opacity === 1)
            return
        const n = hasPicture ? 1 - front : front
        const back = pane(n)
        if (back.key === key && back.status === Image.Ready) {
            swapTo(n)
            return
        }
        back.fill = fill
        back.source = source
    }

    // A picture that failed to load: logged, its layer emptied (it is never
    // the one in front), the old picture left as it is
    function dropFailed(pane) {
        console.warn(`WallpaperSwap: não deu para carregar ${pane.source}`)
        pane.source = ""
    }

    // Layer n is ready: it comes in on top
    function swapTo(n) {
        const incoming = pane(n)
        const old = pane(1 - n)
        incoming.z = 2
        old.z = 1
        incoming.opacity = 0
        incoming.scale = Theme.reduceMotion ? 1 : Theme.wallpaperZoom
        front = n
        swap.incoming = incoming
        swap.restart()
    }

    ParallelAnimation {
        id: swap
        property Item incoming: a
        NumberAnimation {
            target: swap.incoming
            property: "opacity"
            to: 1
            duration: Theme.dur(Theme.wallpaperFade)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDecel
        }
        NumberAnimation {
            target: swap.incoming
            property: "scale"
            to: 1
            duration: Theme.dur(Theme.wallpaperFade)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDecel
        }
        onFinished: {
            // The old one is fully covered now
            root.pane(1 - root.front).opacity = 0
            root.hasPicture = true
            if (root.pending)
                root.load()
        }
    }

    NumberAnimation {
        id: fadeOut
        target: root.pane(root.front)
        property: "opacity"
        to: 0
        duration: Theme.dur(Theme.wallpaperFade)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveAccel
        onFinished: {
            root.hasPicture = false
            if (root.pending)
                root.load()
        }
    }

    component Layer: Image {
        property string fill: "fill"
        readonly property string key: String(source) === "" ? "" : `${source}|${fill}`
        anchors.fill: parent
        opacity: 0
        asynchronous: true
        fillMode: fill === "fit" ? Image.PreserveAspectFit
                : fill === "center" ? Image.Pad
                : fill === "tile" ? Image.Tile
                : Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        // Fill and fit: decoded at the item's size, not the file's 3840 px;
        // centered and tiled keep the picture's own size
        sourceSize: fill === "fill" || fill === "fit" ? Qt.size(root.width, root.height) : undefined
    }

    Layer {
        id: a
        onStatusChanged: {
            if (status === Image.Ready && key === root.key && !(root.hasPicture && root.front === 0))
                root.swapTo(0)
            else if (status === Image.Error)
                root.dropFailed(a)
        }
    }
    Layer {
        id: b
        onStatusChanged: {
            if (status === Image.Ready && key === root.key && !(root.hasPicture && root.front === 1))
                root.swapTo(1)
            else if (status === Image.Error)
                root.dropFailed(b)
        }
    }
}
