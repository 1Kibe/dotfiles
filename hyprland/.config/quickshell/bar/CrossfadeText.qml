import QtQuick
import qs.theme

// A line of text that changes with a crossfade (a new track's title).
Item {
    id: root

    property string text
    property color color: Theme.text
    property font font
    property int elide: Text.ElideRight
    property real rightPadding: 0
    property int front: 0

    implicitHeight: Math.max(a.implicitHeight, b.implicitHeight)

    onTextChanged: {
        const back = front === 0 ? b : a
        if (back.text === text && (front === 0 ? a : b).text !== text) {
            front = front === 0 ? 1 : 0
            return
        }
        if ((front === 0 ? a : b).text === text)
            return
        back.text = text
        front = front === 0 ? 1 : 0
    }

    component Line: Text {
        textFormat: Text.PlainText
        property bool active: false
        width: root.width
        color: root.color
        font: root.font
        elide: root.elide
        rightPadding: root.rightPadding
        opacity: active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.coverFade; easing.type: Easing.InOutSine }
        }
    }

    Line {
        id: a
        active: root.front === 0
    }
    // The first text shows at once; later ones crossfade
    Component.onCompleted: a.text = root.text
    Line {
        id: b
        active: root.front === 1
    }
}
