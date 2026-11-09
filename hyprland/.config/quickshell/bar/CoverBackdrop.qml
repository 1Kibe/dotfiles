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

    property string source        // album art URL; "" keeps the last one while fading out
    property bool shown: false
    property int front: 0         // which of the two layers is visible
    property color shade: Theme.coverShade

    color: Theme.islandFill       // shown under the cover (and without one)
    // Bottom corners only: the center island hangs from the top edge
    // (MediaPanel rounds all four)
    bottomLeftRadius: Theme.barRadius
    bottomRightRadius: Theme.barRadius
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
        if (source === "")
            return
        // Back layer already holds this URL (back to the previous cover): it
        // is loaded, so just swap; a new URL swaps from onReadyChanged below
        const back = front === 0 ? layerB : layerA
        if (String(back.source) !== source)
            back.source = source
        else
            front = front === 0 ? 1 : 0
    }

    component CoverLayer: Item {
        id: layer

        property alias source: image.source
        property bool active: false
        readonly property bool ready: image.status === Image.Ready

        anchors.fill: parent
        // Each layer fades on its own: the old cover fades out while the new
        // one fades in, which makes the crossfade
        opacity: active && ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
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
                root.front = 0
        }
    }
    CoverLayer {
        id: layerB
        active: root.front === 1
        onReadyChanged: {
            if (ready && String(source) === root.source)
                root.front = 1
        }
    }

    // Darken for the clock
    Rectangle {
        anchors.fill: parent
        color: root.shade
    }
}
