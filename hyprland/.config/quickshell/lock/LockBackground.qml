import QtQuick
import qs.theme

// Background of the lock and login screens: a ready-made picture (blur and
// darkening already applied when it was chosen) over plain bgDeep. Without a
// picture, or when it fails to load, only the plain color shows. Shared with
// the login screen.
Rectangle {
    id: root

    // Absolute path of a regular PNG; "" = plain
    property string source: ""

    color: Theme.bgDeep

    Image {
        anchors.fill: parent
        visible: status === Image.Ready
        source: root.source !== "" ? `file://${root.source}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Never decoded larger than a 4K screen, whatever the file says
        sourceSize.width: Math.min(3840, Math.max(1, root.width))
        sourceSize.height: Math.min(3840, Math.max(1, root.height))
    }
}
