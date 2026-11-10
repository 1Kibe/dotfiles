import QtQuick
import qs.theme

// A picture that changes with a crossfade (a new track's cover): the new one
// is loaded in the background and shown only once ready, fading in over the
// old one, which stays fully visible underneath until the fade is over.
// Never a frame with nothing, however slow the new picture is to load.
// An empty source (no cover) fades the picture out: not ready then.
Item {
    id: root

    property string source
    property int sourceSize: 144
    property int front: 0
    // The old picture stays under the new one while it fades in
    property bool swapping: false
    // Source emptied: both pictures fade out until a new one is shown
    property bool cleared: source === ""
    readonly property bool ready: !cleared && (front === 0 ? a : b).status === Image.Ready

    function show(n) {
        cleared = false
        if (front === n)
            return
        front = n
        swapping = true
        swapDone.restart()
    }

    Timer {
        id: swapDone
        interval: Theme.coverFade
        onTriggered: root.swapping = false
    }

    onSourceChanged: {
        if (source === "") {
            cleared = true
            return
        }
        // Back to the picture in front (after an empty source): show it again
        const shown = front === 0 ? a : b
        if (String(shown.source) === source && shown.status === Image.Ready) {
            cleared = false
            return
        }
        const back = front === 0 ? b : a
        if (String(back.source) === source && back.status === Image.Ready)
            show(front === 0 ? 1 : 0)
        else
            back.source = source
    }

    component Layer: Image {
        property bool active: false
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.sourceSize
        sourceSize.height: root.sourceSize
        z: active ? 1 : 0
        // The new one fades in on top; the old one, fully covered by then,
        // fades out after it. Always animated: a Behavior switched on by
        // `active` would come too late, as the opacity changes in the same
        // step
        opacity: root.cleared ? 0 : active ? (status === Image.Ready ? 1 : 0) : (root.swapping ? 1 : 0)
        Behavior on opacity {
            NumberAnimation { duration: Theme.coverFade; easing.type: Easing.OutCubic }
        }
    }

    Layer {
        id: a
        active: root.front === 0
        onStatusChanged: {
            if (status === Image.Ready && String(source) === root.source)
                root.show(0)
        }
    }
    Layer {
        id: b
        active: root.front === 1
        onStatusChanged: {
            if (status === Image.Ready && String(source) === root.source)
                root.show(1)
        }
    }
}
