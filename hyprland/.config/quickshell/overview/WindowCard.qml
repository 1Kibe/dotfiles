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
    readonly property bool hovered: mouse.containsMouse
    signal picked()

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
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.picked()
    }
}
