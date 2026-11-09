import QtQuick
import Quickshell.Widgets
import qs.theme
import "text.js" as Clean

// The user's picture (AccountsService icon) or, without one, the initial in
// an accentLight circle, and the name under it. Shared with the login screen.
Column {
    id: root

    property string name: ""
    // The name as shown: no control or bidi characters, one line
    readonly property string shownName: Clean.clean(name, 60)
    // Absolute path of the picture; a missing or broken file shows the initial
    property string photo: ""
    // false: never open a picture, only the initial (the login screen, which
    // must not decode files from users' folders)
    property bool usePhoto: true
    property int size: Theme.lockAvatarSize
    // The login screen draws the name itself (with "1 de 2")
    property bool showName: true

    spacing: 10

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size
        height: root.size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.accentLight
            visible: picture.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: root.shownName.length > 0 ? root.shownName.charAt(0).toUpperCase() : ""
                textFormat: Text.PlainText
                color: Theme.bgHard
                font.family: Theme.font
                font.pixelSize: root.size * 0.42
                font.weight: Font.DemiBold
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.clear
            visible: picture.status === Image.Ready

            Image {
                id: picture
                anchors.fill: parent
                source: root.usePhoto && root.photo !== "" ? `file://${root.photo}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Twice the circle: sharp on scaled screens
                sourceSize.width: root.size * 2
                sourceSize.height: root.size * 2
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showName
        text: root.shownName
        textFormat: Text.PlainText
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Theme.lockFieldWidth)
        horizontalAlignment: Text.AlignHCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 17
    }
}
