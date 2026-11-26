import QtQuick
import qs.theme

// A color picker (the theme editor's squares): saturation and value in a
// square, the hue in a strip under it, the hex in a field. Every move sends
// `moved` with the color as "#rrggbb"; "Pronto" (or Esc, or a click outside,
// handled by whoever shows it) closes it.
Rectangle {
    id: root

    // The color it opens with ("#rrggbb")
    property string value: ""
    signal moved(string hex)
    signal done()

    width: 232
    height: 266
    radius: Theme.radius
    color: Theme.bgHard
    border.width: 1
    border.color: Theme.bg2

    property real hue: 0
    property real sat: 0
    property real val: 0
    function load(hex) {
        if (!/^#[0-9a-fA-F]{6}$/.test(hex))
            return
        const c = Qt.color(hex)
        hue = Math.max(0, c.hsvHue)
        sat = c.hsvSaturation
        val = c.hsvValue
    }
    Component.onCompleted: load(value)
    onValueChanged: if (hexOf() !== value.toLowerCase()) load(value)
    function hexOf() {
        return String(Qt.hsva(hue, sat, val, 1)).toLowerCase()
    }
    function send() {
        moved(hexOf())
    }

    // Saturation (left to right) and value (top to bottom) at this hue
    Rectangle {
        id: square
        x: 12; y: 12; width: parent.width - 24; height: 150
        radius: 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 1; color: Qt.hsva(root.hue, 1, 1, 1) }
        }
        Rectangle {
            anchors.fill: parent
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "black" }
            }
        }
        Rectangle {
            x: root.sat * square.width - 6; y: (1 - root.val) * square.height - 6
            width: 12; height: 12; radius: 6
            color: "transparent"; border.width: 2; border.color: root.val > 0.5 ? "black" : "white"
        }
        MouseArea {
            anchors.fill: parent
            function at(m) {
                root.sat = Math.max(0, Math.min(1, m.x / width))
                root.val = Math.max(0, Math.min(1, 1 - m.y / height))
                root.send()
            }
            onPressed: m => at(m)
            onPositionChanged: m => { if (pressed) at(m) }
        }
    }
    // The hue
    Rectangle {
        id: strip
        x: 12; y: square.y + square.height + 10; width: square.width; height: 14
        radius: 7
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.hsva(0, 1, 1, 1) }
            GradientStop { position: 0.17; color: Qt.hsva(0.17, 1, 1, 1) }
            GradientStop { position: 0.33; color: Qt.hsva(0.33, 1, 1, 1) }
            GradientStop { position: 0.5; color: Qt.hsva(0.5, 1, 1, 1) }
            GradientStop { position: 0.67; color: Qt.hsva(0.67, 1, 1, 1) }
            GradientStop { position: 0.83; color: Qt.hsva(0.83, 1, 1, 1) }
            GradientStop { position: 1.0; color: Qt.hsva(1, 1, 1, 1) }
        }
        Rectangle {
            x: root.hue * strip.width - 3; y: -2; width: 6; height: strip.height + 4; radius: 3
            color: "transparent"; border.width: 2; border.color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            function at(m) {
                root.hue = Math.max(0, Math.min(0.999, m.x / width))
                root.send()
            }
            onPressed: m => at(m)
            onPositionChanged: m => { if (pressed) at(m) }
        }
    }
    Row {
        x: 12; y: strip.y + strip.height + 12; spacing: 8
        Rectangle { width: 28; height: 28; radius: 6; color: root.hexOf(); border.width: 1; border.color: Theme.bg2 }
        Field {
            width: 104
            mono: true
            value: root.hexOf()
            onAccepted: t => {
                const h = t.trim().toLowerCase()
                if (/^#[0-9a-f]{6}$/.test(h)) {
                    root.load(h)
                    root.send()
                }
            }
        }
        Button { text: "Pronto"; onClicked: root.done() }
    }
}
