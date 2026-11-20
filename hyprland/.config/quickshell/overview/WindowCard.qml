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
    signal dragMoved(point at)

    // The drag: reported in scene coordinates (the screen draws a copy
    // above the middle, which clips); the card itself stays and dims
    property bool dragging: false
    signal dragStarted(point at)
    // The window's final size in the middle (the capture is sized to it,
    // not to every step of the flight)
    property real targetW: width
    property real targetH: height

    readonly property string iconName: /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(String(win.appClass || "")) ? String(win.appClass) : ""
    readonly property string iconPath: iconName === "" ? ""
        : Quickshell.iconPath(iconName, true) || Quickshell.iconPath(iconName.toLowerCase(), true)

    radius: Theme.radius
    color: Theme.bg
    border.width: chosen || hovered ? Theme.focusWidth : 1
    border.color: chosen || hovered ? Theme.focusRing : Theme.bg1
    clip: true
    opacity: dragging ? Theme.overviewDragFade : 1

    // The window, live: only while the overview is open and the window
    // has its Wayland side; else the card's plain fill
    Loader {
        id: shot
        x: 1
        y: strip.height
        width: parent.width - 2
        height: parent.height - strip.height - 1
        active: OverviewState.open && (root.win.toplevel?.wayland ?? null) !== null
        sourceComponent: Component {
            ScreencopyView {
                captureSource: root.win.toplevel?.wayland ?? null
                live: OverviewState.open
                constraintSize: Qt.size(root.targetW, root.targetH)
            }
        }
    }

    // The title strip
    Rectangle {
        id: strip
        width: parent.width
        height: Theme.overviewTitleHeight
        color: Theme.bgHard
        radius: Theme.radius

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.overviewTitlePad
            anchors.rightMargin: Theme.overviewTitlePad
            spacing: Theme.overviewTitleGap

            Image {
                visible: root.iconPath !== ""
                source: root.iconPath
                sourceSize.width: Theme.overviewIcon
                sourceSize.height: Theme.overviewIcon
                Layout.preferredWidth: Theme.overviewIcon
                Layout.preferredHeight: Theme.overviewIcon
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
        onPressed: event => start = mapToItem(null, event.x, event.y)
        onPositionChanged: event => {
            if (!pressed)
                return
            const p = mapToItem(null, event.x, event.y)
            if (!root.dragging && Math.hypot(p.x - start.x, p.y - start.y) > 10) {
                root.dragging = true
                root.dragStarted(start)
            }
            if (root.dragging)
                root.dragMoved(p)
        }
        onReleased: event => {
            if (root.dragging) {
                root.dragging = false
                root.dropped(mapToItem(null, event.x, event.y))
            } else {
                root.picked()
            }
        }
        onCanceled: {
            if (root.dragging) {
                root.dragging = false
                root.dropped(Qt.point(-1, -1))
            }
        }
    }

    // The ×, with the mouse on the card: asks the window to close (the app
    // may ask to save first, as always)
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.overviewCloseInset
        width: Theme.overviewCloseSize
        height: Theme.overviewCloseSize
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
