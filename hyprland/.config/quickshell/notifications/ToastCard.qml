import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "policy.js" as Policy

// One notification on the screen (NotificationToasts stacks them): the
// app's name and the time it came, its icon (a theme icon by name only,
// state/AppIcons), the title in one line, the text in up to 3, the app's
// buttons (up to 3), "N novas" when more of the same app came, and the
// time bar. Urgent: a red border, an X and no time bar while it may stay.
// Everything from outside is plain text, cut by lines and by height. The
// mouse over it holds its time; dragged to the right it leaves the screen
// (it stays in the list). It reads only the cleaned copy
// (NotificationState.entries), never the notification itself.
Item {
    id: root

    required property int cardId
    property int count: 1
    readonly property var entry: NotificationState.entries.find(e => e.id === cardId) ?? null
    readonly property bool urgent: entry !== null && entry.urgent
    // The card's time (reading time, never scaled by the speed)
    readonly property int life: Policy.cardTime(urgent, NotificationState.fullscreen, Theme.toastHold)
    property real elapsed: 0
    // (the tests hold it as the mouse would)
    property bool clockHold: false
    readonly property bool held: hover.hovered || drag.active || clockHold
    signal expired()

    implicitWidth: Theme.toastWidth
    implicitHeight: card.implicitHeight

    function timeText(ms) {
        const d = new Date(ms)
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }

    // One timer while it shows, stopped while held; the bar follows it.
    // The time is the real one gone by (ticks can come late)
    property double last: 0
    Timer {
        id: clock
        interval: 100
        repeat: true
        running: root.entry !== null && !root.held
        onRunningChanged: root.last = Date.now()
        onTriggered: {
            const now = Date.now()
            root.elapsed += now - root.last
            root.last = now
            if (root.elapsed >= root.life) {
                stop()
                root.expired()
            }
        }
    }
    // A new one of the same app: its time starts again
    onCountChanged: elapsed = 0

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: card
        width: root.width
        implicitHeight: column.implicitHeight + 20
        radius: Theme.stripRadius
        color: Theme.cardFill
        border.width: root.urgent ? 1 : 0
        border.color: Theme.red
        x: drag.active ? Math.max(0, drag.translation.x) : 0
        Behavior on x {
            enabled: !drag.active && !Theme.reduceMotion
            NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
        }
        clip: true

        DragHandler {
            id: drag
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (!active && translation.x > Theme.toastWidth / 4)
                    NotificationState.dismissToast(root.cardId)
            }
        }

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // The app's icon by name, else a plain square
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 7
                    color: Theme.bg1
                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        visible: status === Image.Ready
                        asynchronous: true
                        cache: false
                        sourceSize.width: 36
                        sourceSize.height: 36
                        source: root.entry && root.entry.image.kind === "icon" ? AppIcons.icon(root.entry.image.value) : ""
                    }
                }
                // The name always in the same place, plain (anyone can say any name)
                Text {
                    Layout.fillWidth: true
                    text: root.entry ? root.entry.appName + " · " + root.timeText(root.entry.time) : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.fg4
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSizeSmall
                }
                Text {
                    visible: root.count > 1
                    text: `${root.count} novas`
                    textFormat: Text.PlainText
                    color: Theme.accentLight
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSizeSmall
                }
                // Urgent: closed by hand (it stays in the list)
                Text {
                    visible: root.urgent
                    text: String.fromCodePoint(0xF0156)   // nf-md-close
                    textFormat: Text.PlainText
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                    TapHandler {
                        onTapped: NotificationState.dismissToast(root.cardId)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry ? root.entry.summary : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                color: Theme.fg
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumHeight: 3 * (font.pointSize * 2)
                visible: text !== ""
                text: root.entry ? root.entry.body : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 3
                clip: true
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
            // The app's own buttons (what they do comes with the actions)
            RowLayout {
                Layout.fillWidth: true
                visible: root.entry !== null && root.entry.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.entry ? root.entry.actions : []
                    Rectangle {
                        required property var modelData
                        implicitWidth: label.implicitWidth + 16
                        implicitHeight: label.implicitHeight + 8
                        radius: Theme.radius
                        color: Theme.bg1
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.fg
                            font.family: Theme.fontPanels
                            font.pointSize: Theme.fontSize - 1
                        }
                    }
                }
            }
        }

        // The time left (a normal card only)
        Rectangle {
            visible: !root.urgent
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: Theme.toastTimerHeight
            width: parent.width * Math.max(0, 1 - root.elapsed / root.life)
            color: Theme.accentLight
            opacity: 0.6
        }
    }
}
