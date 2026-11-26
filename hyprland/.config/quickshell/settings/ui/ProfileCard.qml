import QtQuick
import qs.theme

import "../../theme/seal.js" as Seal

// One profile as a poster (3:4): its picture filling the card (its
// miniature, cut to fit) with the color seal in the bottom right corner, or,
// with no picture of its own, the seal large in the middle over the
// profile's background; its name under it. Drawn with the profile's colors
// (`colors`: its theme resolved for its flavor and accent), never with the
// Theme of the moment; the frame and the marks are the panel's. The name is
// the profile's own text, shown as plain text. Used by Configurações →
// Perfis and the Super+T carousel (which shows no marks).
Item {
    id: root

    // { roles, named, accent } (theme/palettes.js resolve)
    property var colors: null
    property string name: ""
    // A file URL ("" = no picture: the large seal)
    property string picture: ""
    property bool chosen: false
    property bool focusRing: false
    // "ativo" and "alterado" (the page only)
    property bool marks: false
    property bool active: false
    property bool dirty: false

    implicitWidth: 150
    implicitHeight: poster.height + 26
    readonly property var c: colors ? colors.roles : ({})
    readonly property var pair: colors ? Seal.sealColors(colors.named, String(colors.accent)) : ["red", "blue"]

    Rectangle {
        id: poster
        width: parent.width
        height: Math.round(width * 4 / 3)
        radius: Theme.radius
        color: root.c.bg || Theme.bg1
        clip: true
        Image {
            id: image
            anchors.fill: parent
            visible: root.picture !== "" && status === Image.Ready
            source: root.picture
            fillMode: Image.PreserveAspectCrop
            // (in steps of 64: a resize does not read the file again each step)
            sourceSize: Qt.size(Math.ceil(poster.width / 64) * 64, Math.ceil(poster.height / 64) * 64)
            asynchronous: true
            cache: false
        }
        ColorSeal {
            readonly property bool large: !image.visible
            width: large ? Math.min(Theme.sealLarge, poster.width * 0.6) : Theme.sealSmall
            height: width
            x: large ? (poster.width - width) / 2 : poster.width - width - Theme.sealMargin
            y: large ? (poster.height - height) / 2 : poster.height - height - Theme.sealMargin
            outline: root.c.bgDeep || "transparent"
            thin: root.c.bg2 || "transparent"
            accent: root.colors ? root.colors.accent : "transparent"
            colorA: root.colors ? root.colors.named[root.pair[0]] : "transparent"
            colorB: root.colors ? root.colors.named[root.pair[1]] : "transparent"
        }
        // The marks, over the top left corner
        Row {
            x: 6
            y: 6
            spacing: 4
            visible: root.marks
            Repeater {
                model: (root.active ? ["ativo"] : []).concat(root.dirty ? ["alterado"] : [])
                Rectangle {
                    required property string modelData
                    width: markText.implicitWidth + 10
                    height: markText.implicitHeight + 2
                    radius: height / 2
                    color: modelData === "ativo" ? Theme.accent : Theme.alpha(Theme.bgHard, 0.85)
                    Text {
                        id: markText
                        anchors.centerIn: parent
                        text: parent.modelData
                        textFormat: Text.PlainText
                        color: parent.modelData === "ativo" ? Theme.bgHard : Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
    // The frame: the chosen one in the accent, the keyboard's thicker
    Rectangle {
        width: poster.width
        height: poster.height
        radius: Theme.radius
        color: "transparent"
        border.width: root.focusRing ? 3 : root.chosen ? 2 : 1
        border.color: root.focusRing ? Theme.text : root.chosen ? Theme.accent : Theme.alpha(Theme.fg, 0.15)
    }
    Text {
        anchors.top: poster.bottom
        anchors.topMargin: 6
        width: parent.width
        text: root.name
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        color: root.chosen ? Theme.text : Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
