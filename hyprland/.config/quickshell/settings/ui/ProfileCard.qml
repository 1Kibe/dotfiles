import QtQuick
import QtQuick.Effects
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

    // The frame's width; the picture, the seal and the marks stay inside it
    readonly property int borderWidth: focusRing ? 3 : chosen ? 2 : 1
    // Where the marks and a card's buttons go: this far inside the frame
    readonly property int inset: borderWidth + 8
    readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software

    Rectangle {
        id: poster
        width: parent.width
        height: Math.round(width * 4 / 3)
        radius: Theme.radius
        color: root.c.bg || Theme.bg1
        // The picture, cut to the rounded rectangle inside the frame (a mask
        // of that shape; the software renderer has none: square corners)
        Item {
            id: inner
            x: root.borderWidth
            y: root.borderWidth
            width: poster.width - 2 * root.borderWidth
            height: poster.height - 2 * root.borderWidth
            clip: root.software
            Image {
                id: image
                anchors.fill: parent
                visible: root.picture !== "" && status === Image.Ready && root.software
                source: root.picture
                fillMode: Image.PreserveAspectCrop
                // (in steps of 64: a resize does not read the file again each step)
                sourceSize: Qt.size(Math.ceil(poster.width / 64) * 64, Math.ceil(poster.height / 64) * 64)
                asynchronous: true
                cache: false
            }
            Item {
                id: shape
                anchors.fill: parent
                visible: false
                layer.enabled: root.hasPicture && !root.software
                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(0, Theme.radius - root.borderWidth)
                    color: Theme.text
                }
            }
            MultiEffect {
                anchors.fill: parent
                visible: root.hasPicture && !root.software
                source: image
                maskEnabled: true
                maskSource: shape
            }
            ColorSeal {
                readonly property bool large: !root.hasPicture
                width: large ? Math.min(Theme.sealLarge, inner.width * 0.6) : Theme.sealSmall
                height: width
                x: large ? (inner.width - width) / 2 : inner.width - width - Theme.sealMargin
                y: large ? (inner.height - height) / 2 : inner.height - height - Theme.sealMargin
                outline: root.c.bgDeep || "transparent"
                thin: root.c.bg2 || "transparent"
                accent: root.colors ? root.colors.accent : "transparent"
                colorA: root.colors ? root.colors.named[root.pair[0]] : "transparent"
                colorB: root.colors ? root.colors.named[root.pair[1]] : "transparent"
            }
        }
        // The marks, inside the top left corner
        Row {
            x: root.inset
            y: root.inset
            spacing: 4
            visible: root.marks
            Repeater {
                model: (root.active ? ["ativo"] : []).concat(root.dirty ? ["alterado"] : [])
                Rectangle {
                    required property string modelData
                    width: markText.implicitWidth + 10
                    height: markText.implicitHeight + 2
                    radius: height / 2
                    // ativo in the accent; alterado in yellow, outlined
                    color: modelData === "ativo" ? Theme.accent : Qt.tint(Theme.alpha(Theme.bgHard, 0.92), Theme.alpha(Theme.yellow, 0.2))
                    border.width: modelData === "ativo" ? 0 : 1
                    border.color: Theme.yellow
                    Text {
                        id: markText
                        anchors.centerIn: parent
                        text: parent.modelData
                        textFormat: Text.PlainText
                        color: parent.modelData === "ativo" ? Theme.onAccent : Theme.yellow
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
    readonly property bool hasPicture: root.picture !== "" && image.status === Image.Ready
    // The frame: the chosen one in the accent, the keyboard's thicker
    Rectangle {
        width: poster.width
        height: poster.height
        radius: Theme.radius
        color: Theme.clear
        border.width: root.borderWidth
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
