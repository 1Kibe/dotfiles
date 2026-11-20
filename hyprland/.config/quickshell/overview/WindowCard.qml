import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state
import "../control/lists.js" as Lists

// A window in the overview's middle: a strip on top with the app's icon
// (by the icon theme's name; none, the generic one) and the title, and the
// window under it, live (ScreencopyView), made only while the overview is
// open: closed, no capture runs. The mouse on it, or the keyboard: the
// accent border.
// Title and app name are text from outside: plain text, one line, cleaned.
Rectangle {
    id: root

    // { id (address), title, appClass, ... }
    required property var win
    property bool chosen: false
    readonly property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    signal picked()
    // The × (the window asked to close)
    signal closeClicked()
    // Dropped after a drag, at this point of the scene
    signal dropped(point at)

    // The drag: the card follows the mouse, and goes back to its place
    // when dropped (bound x and y stay untouched)
    property real dragX: 0
    property real dragY: 0
    property bool dragging: false
    transform: Translate {
        x: root.dragX
        y: root.dragY
    }
    Behavior on dragX {
        enabled: !root.dragging
        NumberAnimation { duration: Theme.dur(Theme.motionPanelClose); easing.type: Easing.OutCubic }
    }
    Behavior on dragY {
        enabled: !root.dragging
        NumberAnimation { duration: Theme.dur(Theme.motionPanelClose); easing.type: Easing.OutCubic }
    }
    z: dragging ? 10 : 0

    readonly property string iconName: /^[A-Za-z0-9._-]{1,64}$/.test(String(win.appClass || "")) ? String(win.appClass).toLowerCase() : ""
    readonly property string iconPath: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""

    radius: Theme.radius
    color: Theme.bg
    border.width: chosen || hovered ? Theme.focusWidth : 1
    border.color: chosen || hovered ? Theme.focusRing : Theme.bg1
    clip: true

    // The window, live: only while the overview is open and the window
    // has its Wayland side; else the card's plain fill
    Loader {
        id: shot
        x: 1
        y: strip.height
        width: parent.width - 2
        height: parent.height - strip.height - 1
        active: OverviewState.open && root.win.toplevel !== undefined && root.win.toplevel !== null
                && root.win.toplevel.wayland !== null && root.win.toplevel.wayland !== undefined
        sourceComponent: Component {
            ScreencopyView {
                captureSource: root.win.toplevel.wayland
                live: OverviewState.open
                constraintSize: Qt.size(shot.width, shot.height)
            }
        }
    }

    // The title strip
    Rectangle {
        id: strip
        width: parent.width
        height: 26
        color: Theme.bgHard
        radius: Theme.radius

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Image {
                visible: root.iconPath !== ""
                source: root.iconPath
                sourceSize.width: 16
                sourceSize.height: 16
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }
            Text {
                visible: root.iconPath === ""
                text: String.fromCodePoint(0xF08C6)   // nf-md-application
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                Layout.fillWidth: true
                text: Lists.trim(root.win.title)
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        preventStealing: root.dragging
        property point start
        onPressed: event => start = Qt.point(event.x, event.y)
        onPositionChanged: event => {
            if (!pressed)
                return
            const dx = event.x - start.x, dy = event.y - start.y
            if (!root.dragging && Math.hypot(dx, dy) > 10)
                root.dragging = true
            if (root.dragging) {
                root.dragX = dx
                root.dragY = dy
            }
        }
        onReleased: event => {
            if (root.dragging) {
                root.dragging = false
                root.dropped(mapToItem(null, event.x, event.y))
            } else {
                root.picked()
            }
            root.dragX = 0
            root.dragY = 0
        }
        onCanceled: {
            root.dragging = false
            root.dragX = 0
            root.dragY = 0
        }
    }

    // The ×, with the mouse on the card: asks the window to close (the app
    // may ask to save first, as always)
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3
        width: 20
        height: 20
        radius: width / 2
        visible: root.hovered && !root.dragging
        color: closeMouse.containsMouse ? Theme.danger : Theme.bg1

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0156)   // nf-md-close
            textFormat: Text.PlainText
            color: Theme.red
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }
}
