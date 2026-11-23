import QtQuick
import qs.theme

// An area in the overview's strip: its number and a plain rectangle where
// each of its windows is (no picture). The one shown in the middle has the
// accent border. Also the "Minimizadas · N" card.
Rectangle {
    id: root

    // The label: the area's number or "Minimizadas · N"
    property string label: ""
    // What a dropped window card does here: "area" (moves it to ws), ""
    // (nothing: "Minimizadas")
    property string kind: ""
    property int ws: 0
    // [{ x, y, w, h }], 0..1 of the screen
    property var rects: []
    property bool shown: false
    readonly property bool hovered: mouse.containsMouse
    signal entered()
    signal clicked()
    signal doubleClicked()

    radius: Theme.radius
    color: hovered ? Theme.bg1 : Theme.bg
    border.width: shown ? Theme.focusWidth : 1
    border.color: shown ? Theme.focusRing : Theme.bg1

    // The windows, as plain rectangles
    Item {
        id: screenArea
        anchors.fill: parent
        anchors.margins: Theme.spacing
        anchors.bottomMargin: Theme.itemHeight
        // A window partly off the screen stays inside the card
        clip: true

        Repeater {
            model: root.rects

            Rectangle {
                required property var modelData
                x: modelData.x * screenArea.width
                y: modelData.y * screenArea.height
                width: Math.max(2, modelData.w * screenArea.width)
                height: Math.max(2, modelData.h * screenArea.height)
                radius: Theme.radius / 4
                color: Theme.bg2
                border.width: 1
                border.color: Theme.fg4
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing / 2
        text: root.label
        textFormat: Text.PlainText
        color: root.shown ? Theme.fg : Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}
