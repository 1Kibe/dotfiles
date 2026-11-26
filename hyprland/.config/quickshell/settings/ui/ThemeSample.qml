import QtQuick
import qs.theme

// The theme editor's preview, laid out like the themes' pictures: the
// desktop, a bar (its active workspace in the accent, a date and a battery),
// a control center (four blocks, two on in the accent, a slider, two lines
// of text), an invented notification card with "Abrir", the seven named
// colors and the eight terminal tones. Drawn only with the colors it is
// given (`colors`: { roles, named, ansi, accent, accentLight }), never with
// the Theme of the moment; sizes, radius and fonts are the shell's.
Rectangle {
    id: root

    property var colors: null
    readonly property var c: colors ? colors.roles : ({})
    readonly property var n: colors ? colors.named : ({})
    readonly property var a: colors ? colors.ansi : []
    readonly property color accent: colors ? colors.accent : "transparent"
    readonly property color accentLight: colors ? colors.accentLight : "transparent"

    implicitHeight: column.implicitHeight + 24
    radius: Theme.radius
    color: c.bgDeep || "transparent"
    clip: true

    Column {
        id: column
        x: 12; y: 12
        width: parent.width - 24
        spacing: 10
        // The bar
        Rectangle {
            width: parent.width; height: 28; radius: Theme.barRadius
            color: root.c.bgHard || "transparent"
            Row {
                x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 18; height: 16; radius: 5
                        color: index === 1 ? root.accent : (root.c.bg1 || "transparent")
                        Text { anchors.centerIn: parent; text: index + 1; font.family: Theme.font; font.pointSize: Theme.fontSize - 3
                               color: index === 1 ? (root.c.bgHard || "transparent") : (root.c.fg || "transparent") }
                    }
                }
            }
            SampleLine { anchors.centerIn: parent; text: "qui 26 nov  12:34"; color: root.c.text || "transparent" }
            SampleLine { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                   text: "󰁹 80%"; color: root.c.text || "transparent" }
        }
        // The control center
        Rectangle {
            width: parent.width; height: center.implicitHeight + 20; radius: Theme.radius
            color: root.c.bg || "transparent"
            Column {
                id: center
                x: 10; y: 10; width: parent.width - 20; spacing: 8
                Grid {
                    columns: 2; spacing: 6
                    Repeater {
                        model: [["Rede", true], ["Bluetooth", false], ["Não perturbe", false], ["Luz noturna", true]]
                        Rectangle {
                            required property var modelData
                            width: (center.width - 6) / 2; height: 30; radius: 8
                            color: modelData[1] ? root.accent : (root.c.bg1 || "transparent")
                            SampleLine { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16; text: modelData[0]
                                   color: modelData[1] ? (root.c.bgHard || "transparent") : (root.c.fg || "transparent") }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: root.c.bg2 || "transparent"
                    Rectangle { width: parent.width * 0.65; height: 6; radius: 3; color: root.accentLight }
                }
                SampleLine { width: parent.width; text: "Texto da Central"; color: root.c.fg || "transparent" }
                SampleLine { width: parent.width; text: "Texto apagado · 12:34"; color: root.c.fg4 || "transparent" }
            }
        }
        // An invented notification
        Rectangle {
            width: parent.width; height: card.implicitHeight + 20; radius: Theme.radius
            color: root.c.bg || "transparent"
            Column {
                id: card
                x: 10; y: 10; width: parent.width - 20; spacing: 4
                SampleLine { width: parent.width; text: "Exemplo · agora"; color: root.c.fg4 || "transparent" }
                SampleLine { width: parent.width; text: "Notificação de exemplo"; color: root.c.fg || "transparent"; font.bold: true }
                SampleLine { width: parent.width; text: "Texto inventado, só para ver as cores."; color: root.c.fg2 || "transparent" }
                Rectangle {
                    width: 56; height: 22; radius: 6; color: root.c.bg1 || "transparent"
                    SampleLine { anchors.centerIn: parent; text: "Abrir"; color: root.c.fg || "transparent" }
                }
            }
        }
        // The named colors and the terminal's
        Row {
            spacing: 4
            Repeater {
                model: ["yellow", "orange", "red", "green", "aqua", "blue", "purple"]
                Rectangle { required property string modelData
                            width: (column.width - 24) / 7; height: 16; radius: 4; color: root.n[modelData] || "transparent" }
            }
        }
        Row {
            spacing: 3
            Repeater {
                model: 8
                Rectangle { required property int index
                            width: (column.width - 21) / 8; height: 14; radius: 3; color: root.a[index] || "transparent"
                            border.width: 1; border.color: root.c.bg2 || "transparent" }
            }
        }
    }
}
