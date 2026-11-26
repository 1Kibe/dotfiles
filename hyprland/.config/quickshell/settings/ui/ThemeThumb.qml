import QtQuick
import qs.theme

// One theme in miniature (Configurações → Temas): a desktop, a bar, a panel
// hanging from it and three of its colors, drawn with the colors it is given
// (`colors`: the theme resolved for the chosen flavor and accent), never with
// the Theme of the moment. The name is the theme's own text, shown as plain
// text. Clicking it picks the theme.
Item {
    id: root

    // { roles, named, accent, accentLight } (theme/palettes.js resolve)
    property var colors: null
    property string name: ""
    property bool chosen: false
    signal picked()

    implicitWidth: 150
    implicitHeight: 112
    readonly property var c: colors ? colors.roles : ({})
    readonly property var n: colors ? colors.named : ({})

    Rectangle {
        id: screen
        width: parent.width
        height: 84
        radius: Theme.radius
        color: root.c.bgDeep || "transparent"
        border.width: root.chosen ? 2 : 1
        border.color: root.chosen ? Theme.accent : Theme.alpha(Theme.fg, 0.15)
        clip: true
        // The bar, with its accent's workspace
        Rectangle {
            x: 6; y: 6; width: parent.width - 12; height: 12; radius: 4
            color: root.c.bgHard || "transparent"
            Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 6; radius: 2
                        color: root.colors ? root.colors.accent : "transparent" }
            Rectangle { anchors.centerIn: parent; width: 24; height: 3; radius: 1.5; color: root.c.text || "transparent" }
        }
        // A panel hanging from it
        Rectangle {
            x: parent.width - 66; y: 18; width: 60; height: 54; radius: 6
            color: root.c.bg || "transparent"
            Column {
                x: 6; y: 6; spacing: 4
                Rectangle { width: 40; height: 3; radius: 1.5; color: root.c.fg || "transparent" }
                Rectangle { width: 30; height: 3; radius: 1.5; color: root.c.fg4 || "transparent" }
                Rectangle { width: 48; height: 10; radius: 3; color: root.colors ? root.colors.accent : "transparent" }
                Rectangle { width: 48; height: 10; radius: 3; color: root.c.bg1 || "transparent" }
            }
        }
        // Three of its colors
        Row {
            x: 8; y: parent.height - 18; spacing: 4
            Repeater {
                model: ["red", "green", "blue"]
                Rectangle { required property string modelData
                            width: 10; height: 10; radius: 5; color: root.n[modelData] || "transparent" }
            }
        }
    }
    Text {
        anchors.top: screen.bottom
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
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
