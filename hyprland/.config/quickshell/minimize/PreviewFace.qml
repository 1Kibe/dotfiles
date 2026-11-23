import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import "../control/lists.js" as Lists

// What the preview of a minimized window shows: "App · title" and the
// picture taken when it was hidden (a file of the session's runtime
// directory); with no picture, the app's icon, big. The preview keeps two,
// crossfading from one window to the next.
Item {
    id: root

    // The entry ({ cls, title, shot, ... }); null: empty (nothing loaded)
    property var entry: null
    readonly property string iconPath: entry ? AppIcons.icon(entry.cls) : ""
    readonly property bool hasShot: entry !== null && entry.shot !== ""
    // Something to show: the picture loaded (or failed), or no picture
    readonly property bool ready: entry !== null && (!hasShot || shot.status === Image.Ready || shot.status === Image.Error)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.minimizeMargin
        spacing: Theme.previewGap

        Text {
            Layout.fillWidth: true
            // "App · title"; just one when they are the same (a terminal)
            text: {
                if (!root.entry)
                    return ""
                const cls = root.entry.cls || "", title = root.entry.title || ""
                const parts = title.toLowerCase() === cls.toLowerCase() ? [cls] : [cls, title]
                return Lists.trim(parts.filter(t => t !== "").join(" · "))
            }
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        Item {
            id: picture
            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                id: shot
                anchors.fill: parent
                visible: root.hasShot
                source: root.hasShot ? "file://" + root.entry.shot : ""
                // Decoded at the card's size, not the screen's
                sourceSize.width: picture.width
                sourceSize.height: picture.height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Text {
                anchors.centerIn: parent
                visible: root.entry !== null && !root.hasShot && root.iconPath === ""
                text: String.fromCodePoint(0xF08C6)   // nf-md-application
                textFormat: Text.PlainText
                color: Theme.accentLight
                font.family: Theme.font
                font.pointSize: Theme.previewIcon * 0.75
            }
            Image {
                anchors.centerIn: parent
                visible: root.entry !== null && !root.hasShot && root.iconPath !== ""
                source: root.entry !== null && !root.hasShot ? root.iconPath : ""
                sourceSize.width: Theme.previewIcon
                sourceSize.height: Theme.previewIcon
            }
        }
    }
}
