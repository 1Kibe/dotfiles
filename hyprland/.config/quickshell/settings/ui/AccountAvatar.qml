import QtQuick
import Quickshell.Widgets
import qs.theme

// An account's picture: its photo (a file of the cache, from
// state/CodeAccounts.photoSource; "" for none), else its letter. Hidden: a
// neutral circle with its number, and no photo loaded at all. A photo that
// does not load shows the letter, and is not tried again until its source
// changes. Nothing of the account is logged.
Item {
    id: root

    property string photo: ""
    property string letter: "?"
    property int number: 1
    property bool hidden: false
    property real size: 24

    implicitWidth: size
    implicitHeight: size

    readonly property bool showPhoto: !hidden && picture.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.hidden ? Theme.bg1 : Theme.bg2
        visible: !root.showPhoto

        Text {
            anchors.centerIn: parent
            text: root.hidden ? String(root.number) : root.letter
            textFormat: Text.PlainText
            color: root.hidden ? Theme.gray : Theme.fg
            font.family: Theme.fontPanels
            font.pixelSize: root.size * 0.46
            font.weight: Font.DemiBold
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.clear
        visible: root.showPhoto

        Image {
            id: picture
            anchors.fill: parent
            source: root.hidden ? "" : root.photo
            asynchronous: true
            cache: false
            retainWhileLoading: false
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 48
            sourceSize.height: 48
        }
    }
}
