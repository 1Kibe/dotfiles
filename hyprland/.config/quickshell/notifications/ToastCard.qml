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
// (NotificationState.entries), never the notification itself, and shows a
// copy of its own: with the mouse over it, a new arrival only changes the
// count; the text and the buttons wait until the mouse leaves. For 400 ms
// after it shows or changes, the pointer does nothing on it. Its time runs
// only while the pile shows it (active).
Item {
    id: root

    required property int cardId
    property int count: 1
    // The pile shows it now (on the focused monitor, nothing over it)
    property bool active: true
    readonly property var entry: NotificationState.entries.find(e => e.id === cardId) ?? null
    // What it shows: the entry, kept while the mouse is over it and after
    // the entry is gone (a card sliding out)
    property var shown: null
    // Anything the card shows differs (then the pointer waits again)
    function differs(a, b) {
        return a === null || b === null || a.id !== b.id || a.appName !== b.appName || a.summary !== b.summary
               || a.body !== b.body || a.urgent !== b.urgent || JSON.stringify(a.image) !== JSON.stringify(b.image)
               || JSON.stringify(a.actions) !== JSON.stringify(b.actions)
    }
    function refresh() {
        if (entry !== null && (shown === null || !hover.hovered)) {
            const changed = differs(shown, entry)
            shown = entry
            if (changed)
                arm()
        }
    }
    onEntryChanged: refresh()
    // Shown again (the pile back): the pointer waits again
    onActiveChanged: {
        if (active)
            arm()
    }
    Component.onCompleted: refresh()
    // The pointer is ignored for 400 ms after a change (a click meant for
    // what was there before never lands on what came)
    property bool armed: false
    function arm() {
        armed = false
        armTimer.restart()
    }
    Timer {
        id: armTimer
        interval: 400
        onTriggered: root.armed = true
    }
    readonly property bool urgent: shown !== null && shown.urgent

    // A click: the card (index -1: the app's default action and its
    // window) or a button (its own action). Each one holds its own press
    // (index -> id): the card's never takes a button's. At the release it
    // acts only if the card still shows that same notification, with the
    // same text (a new one, or a change, under the pointer never gets the
    // click). The card leaves the screen by its place (cardId), which may
    // already hold another one of the same app
    property var presses: ({})
    signal acted(string what, int id, int index)
    function press(index) {
        const p = Object.assign({}, presses)
        delete p[index]
        if (armed && shown !== null)
            p[index] = shown.id
        presses = p
        return p[index] !== undefined
    }
    function cancel(index) {
        const p = Object.assign({}, presses)
        delete p[index]
        presses = p
    }
    function release(index) {
        const id = presses[index]
        cancel(index)
        const now = shown !== null ? (NotificationState.entries.find(e => e.id === shown.id) ?? null) : null
        if (id === undefined || !armed || shown === null || id !== shown.id || (now !== null && differs(shown, now)))
            return false
        const done = index < 0 ? NotificationState.open(id) : NotificationState.invoke(id, index)
        if (!done)
            return false
        NotificationState.dismissToast(cardId)
        acted(index < 0 ? "cartao" : "botao", id, index)
        return true
    }
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
        running: root.active && root.shown !== null && !root.held
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
    // A new one of the same app (or another one in its place): its time
    // starts again
    onCountChanged: elapsed = 0
    onCardIdChanged: elapsed = 0

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) root.refresh()
    }
    // Text heights: a line's height cuts what stacks marks over it
    FontMetrics {
        id: small
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSizeSmall
    }
    FontMetrics {
        id: normal
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize
    }
    FontMetrics {
        id: bodyFont
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
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

        // The card's own click (the buttons and the X take theirs first:
        // each grab is exclusive)
        TapHandler {
            enabled: root.armed
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onPressedChanged: {
                if (pressed)
                    root.press(-1)
            }
            onTapped: root.release(-1)
            onCanceled: root.cancel(-1)
        }

        DragHandler {
            id: drag
            enabled: root.armed
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
                        source: root.shown && root.shown.image.kind === "icon" ? AppIcons.icon(root.shown.image.value) : ""
                    }
                }
                // The name always in the same place, plain (anyone can say any name)
                Text {
                    Layout.fillWidth: true
                    Layout.maximumHeight: small.height
                    clip: true
                    // A shell's name from outside: "externo" after it
                    text: root.shown ? root.shown.appName + (root.shown.external ? " (externo)" : "") + " · " + root.timeText(root.shown.time) : ""
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
                        enabled: root.armed
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: NotificationState.dismissToast(root.cardId)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumHeight: normal.height
                clip: true
                visible: text !== ""
                text: root.shown ? root.shown.summary : ""
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
                Layout.maximumHeight: Math.ceil(3 * bodyFont.lineSpacing)
                visible: text !== ""
                text: root.shown ? root.shown.body : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 3
                clip: true
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
            // The app's own buttons
            RowLayout {
                Layout.fillWidth: true
                visible: root.shown !== null && root.shown.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.shown ? root.shown.actions : []
                    Rectangle {
                        required property var modelData
                        id: button
                        // At most a third of the card: a long text is cut
                        Layout.maximumWidth: (Theme.toastWidth - 20 - 12) / 3
                        implicitWidth: label.implicitWidth + 16
                        implicitHeight: bodyFont.height + 8
                        clip: true
                        radius: Theme.radius
                        color: Theme.bg1
                        // Its own click, held from the press (never the card's)
                        TapHandler {
                            enabled: root.armed
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onPressedChanged: {
                                if (pressed)
                                    root.press(button.modelData.index)
                            }
                            onTapped: root.release(button.modelData.index)
                            onCanceled: root.cancel(button.modelData.index)
                        }
                        Text {
                            id: label
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 16)
                            height: bodyFont.height
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
