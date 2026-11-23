import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state
import "../control/lists.js" as Lists
import "layout.js" as Cards

// A window in the overview's middle: the card is the window's photo
// (ScreencopyView), with the Theme's border and corners, taken when the
// card appears (the overview opening, or another area shown in the middle)
// and never updated, as a capture running all the time cost a lot. Made
// only while the overview is open: closed, no capture exists. Under the
// card, outside it, its label: the app's icon (by the icon theme's name;
// none, the generic one) and "app · title", one line; the label stays at
// the card's place while the card flies, fading with the veil. The mouse
// on it, or the keyboard: the accent border and the label lit.
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
    // The label's place, in the card's coordinates (under the card's final
    // place, not under the flying card), and its opacity (the veil's)
    property real labelX: 0
    property real labelY: height
    property real labelOpacity: 1

    readonly property string iconPath: AppIcons.icon(win.appClass)

    readonly property bool lit: chosen || hovered
    radius: Theme.radius
    color: Theme.bg
    opacity: dragging ? Theme.overviewDragFade : 1

    // The window's photo, in the card's rounded shape: only while the
    // overview is open and the window has its Wayland side; else the
    // card's plain fill
    Item {
        id: photo
        anchors.fill: parent
        layer.enabled: shot.active
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: photoMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Loader {
            id: shot
            anchors.fill: parent
            active: OverviewState.open && (root.win.toplevel?.wayland ?? null) !== null
            sourceComponent: Component {
                ScreencopyView {
                    captureSource: root.win.toplevel?.wayland ?? null
                    // Running only until the first frame comes: then it
                    // stays still, that frame kept
                    property bool taken: false
                    live: !taken
                    onHasContentChanged: {
                        if (hasContent)
                            taken = true
                    }
                    constraintSize: Qt.size(root.targetW, root.targetH)
                }
            }
        }
    }
    Item {
        id: photoMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.fg
        }
    }
    // The border, over the photo
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.clear
        border.width: root.lit ? Theme.focusWidth : 1
        border.color: root.lit ? Theme.focusRing : Theme.bg1
    }

    // The label, under the card's place
    RowLayout {
        x: root.labelX + (root.targetW - width) / 2
        y: root.labelY
        height: Theme.overviewLabelHeight
        width: Math.min(implicitWidth, root.targetW)
        spacing: Theme.overviewLabelGap
        opacity: root.labelOpacity

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
            color: root.lit ? Theme.fg : Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            id: labelText
            Layout.fillWidth: true
            Layout.maximumWidth: root.targetW - Theme.overviewIcon - Theme.overviewLabelGap
            text: Cards.label(Lists.trim(root.win.appClass), Lists.trim(root.win.title))
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
            color: root.lit ? Theme.fg : Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
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
