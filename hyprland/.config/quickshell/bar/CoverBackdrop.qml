import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme

// The album cover, cropped, heavily blurred and darkened so white text on
// it stays readable (like Spotify's Hazy theme). Fades in and out and
// crossfades when the cover changes. Used behind the center island and the
// music panel; the corners and the shade are set by each one.
ClippingRectangle {
    id: root

    property string source        // album art URL; "" fades the covers out (the island's color stays)
    property bool shown: false
    property int front: 0         // which of the two layers is visible
    property color shade: Theme.coverShade

    color: Theme.islandFill       // shown under the cover (and without one)
    // The corners away from the screen's edge only: the center island hangs
    // from the bar's edge (the top, or the bottom with the bar there)
    bottomLeftRadius: Theme.barAtBottom ? 0 : Theme.barRadius
    bottomRightRadius: Theme.barAtBottom ? 0 : Theme.barRadius
    topLeftRadius: Theme.barAtBottom ? Theme.barRadius : 0
    topRightRadius: Theme.barAtBottom ? Theme.barRadius : 0
    opacity: shown ? 1 : 0
    // Slower in than out, like the panels
    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Theme.animNormal : Theme.animFast
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    // New cover: load it into the hidden layer, swap when it is ready
    onSourceChanged: {
        if (source === "") {
            cleared = true
            return
        }
        // Back to the cover in front (after an empty source): show it again
        const shownLayer = front === 0 ? layerA : layerB
        if (String(shownLayer.source) === source && shownLayer.ready) {
            cleared = false
            return
        }
        // Back layer already holds this URL (back to the previous cover): it
        // is loaded, so just swap; a new URL swaps from onReadyChanged below
        const back = front === 0 ? layerB : layerA
        if (String(back.source) !== source)
            back.source = source
        else
            show(front === 0 ? 1 : 0)
    }

    // The old cover stays under the new one while it fades in
    property bool swapping: false
    // Source emptied (a player without a cover): both covers fade out until
    // a new one is shown
    property bool cleared: false
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

    component CoverLayer: Item {
        property alias source: image.source
        property bool active: false
        readonly property bool ready: image.status === Image.Ready

        anchors.fill: parent
        // The new cover fades in on top of the old one, which stays fully
        // visible underneath until the fade is over: never a frame of the
        // bare background between two covers
        z: active ? 1 : 0
        opacity: root.cleared ? 0 : active ? (ready ? 1 : 0) : (root.swapping ? 1 : 0)
        // Always animated (see CrossfadeImage): the old cover, covered by
        // then, fades out after the new one is in
        Behavior on opacity {
            NumberAnimation { duration: Theme.coverFade; easing.type: Easing.OutCubic }
        }
        // Cached as a texture: the blur runs again only when the cover changes
        layer.enabled: true

        Image {
            id: image
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 96      // small on purpose: it is blurred anyway
            sourceSize.height: 96
            asynchronous: true
            // Only the blurred copy below is drawn
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: image
            // No padding: the blur stays inside the cover's rectangle. Full blur
            // and little color leave only a soft tint of the cover.
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
        }
    }

    CoverLayer {
        id: layerA
        active: root.front === 0
        // Swap only if this layer still holds the wanted cover: the source may
        // have changed again while it was loading
        onReadyChanged: {
            if (ready && String(source) === root.source)
                root.show(0)
        }
    }
    CoverLayer {
        id: layerB
        active: root.front === 1
        onReadyChanged: {
            if (ready && String(source) === root.source)
                root.show(1)
        }
    }

    // Darken for the clock: over both covers (the new one is raised while
    // it fades in)
    Rectangle {
        anchors.fill: parent
        z: 2
        color: root.shade
    }
}
