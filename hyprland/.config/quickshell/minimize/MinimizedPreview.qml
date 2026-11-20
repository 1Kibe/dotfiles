import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import "../control/lists.js" as Lists

// The preview of a minimized window, next to the open strip: "App ·
// title" and the picture taken when it was hidden (a file of the
// session's runtime directory); with no picture, the app's icon, big.
// Fades in with a short scale (reduce motion: the fade only).
Rectangle {
    id: root

    // The entry ({ cls, title, shot, ... }); null: hidden
    property var entry: null
    readonly property string iconPath: entry && /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(entry.cls)
        ? (Quickshell.iconPath(entry.cls, true) || Quickshell.iconPath(entry.cls.toLowerCase(), true)) : ""

    width: Theme.previewWidth
    height: Theme.previewHeight
    radius: Theme.radius
    color: Theme.stripFill
    clip: true
    opacity: entry ? 1 : 0
    scale: entry || Theme.reduceMotion ? 1 : 0.96
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: Theme.dur(Theme.animFast) }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.dur(Theme.animFast) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.minimizeMargin
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: root.entry ? Lists.trim([root.entry.cls, root.entry.title].filter(t => t !== "").join(" · ")) : ""
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                anchors.fill: parent
                visible: root.entry !== null && root.entry.shot !== ""
                source: root.entry && root.entry.shot !== "" ? "file://" + root.entry.shot : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Text {
                anchors.centerIn: parent
                visible: root.entry !== null && root.entry.shot === "" && root.iconPath === ""
                text: String.fromCodePoint(0xF08C6)   // nf-md-application
                textFormat: Text.PlainText
                color: Theme.accentLight
                font.family: Theme.font
                font.pointSize: Theme.fontSize * 3
            }
            Image {
                anchors.centerIn: parent
                visible: root.entry !== null && root.entry.shot === "" && root.iconPath !== ""
                source: root.iconPath
                sourceSize.width: 48
                sourceSize.height: 48
            }
        }
    }
}
