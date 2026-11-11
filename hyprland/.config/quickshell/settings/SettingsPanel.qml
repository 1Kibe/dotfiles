import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import qs.bar
import "ui"

// The settings (Super+S): drawn in the bar's own window (the frame, Bar.qml),
// on the screen's left edge from x = 0, from the bar down to the bottom. One
// shape with the bar: the bar first stretches its left end over its side gap to
// the screen's edge and squares that corner (edgeStep, read by Bar.qml), then
// the body slides out under it (progress); the only concave corner is where the
// body's right side meets the bar, and the bottom corners touch the screen's
// edge and stay square. One clock drives both (bar/EdgeTimeline); closing runs
// it backwards: the body goes back first, the bar rounds its corner at the end.
// Bar/SettingsZone keeps the windows out of its way.
//
// The frame always has the screen's height (Bar.qml), so opening and closing
// never resize it. Closing: the rows leave, then the panel slides back. Esc, X
// and Super+S close it; a click outside does not, so the windows beside it stay
// usable.
Item {
    id: root

    required property var frame            // the bar's window (Bar.qml)
    required property string monitorName

    readonly property bool open: ShellState.isOpen("settings", monitorName)
    property string page: "tema"
    readonly property bool overCapture: false

    // The timeline's clock (0 = closed, 1 = open); what the frame reads to
    // stretch the bar's left end (Bar.qml) and the body's own part
    // (0 = out of the screen, 1 = open; reduce motion: the fade)
    property alias u: timeline.u
    readonly property string edgeSide: "left"
    readonly property real edgeStep: timeline.barStep
    readonly property real progress: timeline.panelStep

    // What the frame reads (Bar.qml): its room under the bar and the
    // clickable pieces (body and concave corner; the bar's stretched end is
    // the frame's)
    readonly property real roomHeight: frame && frame.screen ? frame.screen.height - Theme.barHeight : Theme.panelRoom
    readonly property Region maskRegion: Region {
        item: bodyArea
        Region { item: cornerArea }
    }

    parent: frame ? frame.panelLayer : null
    visible: false
    // The panel itself stays at the window's corner: only the slider inside
    // moves, so the clickable pieces below can follow the slide with their
    // own geometry (a Region does not see its item's parent moving)
    x: 0
    y: 0
    width: Theme.gap + shape.implicitWidth
    height: Theme.barHeight + root.roomHeight
    // Reduce motion fades instead of sliding
    opacity: Theme.reduceMotion ? progress : 1
    // Where the slider is: -its width (out of the screen) to 0 (open)
    readonly property real slide: Theme.reduceMotion ? 0 : Math.round(-shape.implicitWidth * (1 - progress))
    // How much of the body is on the screen
    readonly property real visibleWidth: Math.max(0, Theme.settingsWidth + slide)

    // Back to the first page each time, unless a page was asked for (IPC
    // open(page) or a search)
    Connections {
        target: ShellState
        function onSettingsPageChanged() {
            if (ShellState.settingsPage !== "")
                root.page = ShellState.settingsPage
        }
    }

    onOpenChanged: {
        if (open) {
            if (!visible) {
                timeline.reset()
                page = ShellState.settingsPage !== "" ? ShellState.settingsPage : "tema"
                sidebar.hideAll()
                pageView.hideAll()
            }
            visible = true
            // A font or cursor installed since the last time shows up
            SystemLists.refresh()
            ShellState.settingsOn = monitorName
            frame.showPanel(root)
            timeline.open()
            sidebar.playIn()
            pageView.playIn(Theme.cascadeStart)
            content.forceActiveFocus()
        } else {
            if (visible) {
                sidebar.playOut()
                pageView.playOut()
                timeline.close()
            }
        }
    }

    function hidden() {
        // (the timeline is back at 0: this runs at its end)
        visible = false
        if (ShellState.settingsOn === monitorName)
            ShellState.settingsOn = ""
        frame.hidePanel(root)
    }

    // The rows start leaving first; then the timeline runs backwards
    EdgeTimeline {
        id: timeline
        closeDelay: Theme.cascadeOutItem
        onClosed: root.hidden()
    }

    // Mask pieces (see maskRegion): the visible part of the body and of the
    // concave corner, from the slide
    Item {
        id: bodyArea
        y: Theme.barHeight
        width: Math.max(0, Theme.settingsWidth + root.slide)
        height: root.roomHeight
    }
    Item {
        id: cornerArea
        x: Theme.settingsWidth + root.slide
        y: Theme.barHeight
        width: shape.flareReach
        height: width
    }

    // What slides: the body from the bar down (square at the bottom, the
    // concave corner only on the right, growing with the progress) and the
    // content
    Item {
        id: slider
        x: root.slide
        y: Theme.barHeight
        width: shape.implicitWidth
        height: root.roomHeight

        AttachedShape {
            id: shape
            flareLeft: false
            flareRight: true
            roundBottomLeft: false
            roundBottomRight: false
            bodyWidth: Theme.settingsWidth
            bodyHeight: root.roomHeight
            progress: root.progress
            unroll: false
            width: implicitWidth
            height: implicitHeight
        }

        // The content: the list on the left, the page on the right
        Item {
            id: content
            width: Theme.settingsWidth
            height: root.roomHeight
            focus: true
            Keys.onEscapePressed: ShellState.close()

            Sidebar {
                id: sidebar
                width: 250
                height: parent.height
                page: root.page
                onPicked: p => {
                    if (p === root.page)
                        return
                    root.page = p
                    pageView.playIn(0)
                }
                onSearched: (p, card) => {
                    root.page = p
                    Qt.callLater(() => {
                        pageView.playIn(0)
                        pageView.showCard(card)
                    })
                }
            }
            Rectangle {
                x: sidebar.width
                y: 12
                width: 1
                height: parent.height - 24
                color: Theme.bg1
            }
            SchemaPage {
                id: pageView
                x: sidebar.width + 1
                width: parent.width - x
                height: parent.height
                page: root.page
            }

            // Close
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                width: 28
                height: 28
                radius: Theme.radius
                color: closeMouse.containsMouse ? Theme.veil : Theme.clear
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize + 1
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.close()
                }
            }
        }
    }
}
