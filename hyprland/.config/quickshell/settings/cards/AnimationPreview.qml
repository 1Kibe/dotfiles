import QtQuick
import qs.theme
import qs.bar
import "../ui"

// "Prévia da animação" (Configurações → Fontes e animações): a panel that
// opens from a bar and closes again, with the panels' own times and curves
// times the chosen speed, or fading when motion is reduced. It plays when
// asked (the button), never on its own.
Item {
    id: root

    implicitHeight: 120

    property bool open: false
    property real progress: 0

    function play() {
        open = !open
        if (open) {
            leave.stop()
            enter.restart()
        } else {
            enter.stop()
            leave.restart()
        }
    }

    NumberAnimation {
        id: enter
        target: root
        property: "progress"
        to: 1
        duration: Theme.dur(Theme.motionPanelOpen)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveDecel
    }
    NumberAnimation {
        id: leave
        target: root
        property: "progress"
        to: 0
        duration: Theme.dur(Theme.motionPanelClose)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveAccel
    }

    Rectangle {
        id: stage
        width: parent.width - button.width - 16
        height: parent.height
        radius: Theme.radius
        color: Theme.bgDeep
        clip: true

        Item {
            id: bar
            x: Theme.gap
            width: parent.width - 2 * Theme.gap
            height: Theme.barHeight
            BarStrip {
                anchors.fill: parent
            }
        }
        // Reduce motion: the whole panel fades instead of unrolling
        AttachedShape {
            x: (stage.width - implicitWidth) / 2
            y: Theme.barHeight
            width: implicitWidth
            height: implicitHeight
            bodyWidth: 160
            bodyHeight: 70
            progress: Theme.reduceMotion ? (root.progress > 0 ? 1 : 0) : root.progress
            opacity: Theme.reduceMotion ? root.progress : 1
        }
    }

    Button {
        id: button
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.open ? "Fechar" : "Abrir"
        icon: "󰐊"
        onClicked: root.play()
    }
}
