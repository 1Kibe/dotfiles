import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.notifications

// The clock's panel (Super+N, the bell, the clock without music): the month
// on the left, the notifications kept on the right (NotificationList), and
// at the bottom "Limpar tudo", Não perturbe and, when some were refused
// (the pace, the caps, an empty text), how many. Hangs centered under the
// center island; one panel at a time (it and the music panel take turns).
// Opening it marks everything read (the count goes, nothing is deleted),
// only while it really shows: never locked, never under the overview; the
// ones that were new keep their bright title while it stays open. Its
// content exists only while it shows (nothing is built with it closed),
// and never locked or during a quick print.
AttachedPanel {
    id: root

    required property string monitorName
    centered: true
    panelWidth: Theme.clockPanelWidth

    readonly property bool showing: visible && open && !NotificationState.locked && !OverviewState.open
    // The ones not read at the opening
    property var freshIds: []
    onShowingChanged: {
        if (showing) {
            freshIds = NotificationState.entries.filter(e => !e.read).map(e => e.id)
            NotificationState.markAllRead()
            // The cards on screen are in the list now
            NotificationState.clearScreen()
        }
    }
    // Arrivals and updates while it shows are read too (and new to the eye)
    Connections {
        target: NotificationState
        function onArrived(id, where) {
            if (root.showing) {
                root.freshIds = root.freshIds.concat([id])
                NotificationState.markAllRead()
            }
        }
    }
    // The texts never show locked or in a quick print
    readonly property bool contentShown: visible && !NotificationState.locked && !CaptureState.printing
    // An overlay while it shows (the minimized windows' photos wait)
    onVisibleChanged: ShellState.setOverlay("relogio:" + monitorName, visible)
    Component.onDestruction: ShellState.setOverlay("relogio:" + monitorName, false)

    readonly property int refused: (NotificationState.dropped.text || 0) + (NotificationState.dropped.rate || 0)
                                   + (NotificationState.dropped.cap || 0)

    // (the tests read it: the content exists only while it shows)
    readonly property bool built: content.item !== null

    Loader {
        id: content
        Layout.fillWidth: true
        Layout.margins: 8
        active: root.contentShown
        sourceComponent: RowLayout {
            spacing: 12

            CalendarView {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 7 * Theme.calendarCell
                Layout.fillWidth: false
            }
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Theme.bg1
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notificações"
                        textFormat: Text.PlainText
                        color: Theme.fg
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: NotificationState.entries.length > 0
                        text: "Limpar tudo"
                        textFormat: Text.PlainText
                        color: Theme.fg4
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: NotificationState.clearAll()
                        }
                    }
                }
                NotificationList {
                    Layout.fillWidth: true
                    maxHeight: 360
                    fresh: root.freshIds
                }
                // Não perturbe while this shell has the name; another program
                // with it: said once the first check answered
                RowLayout {
                    Layout.fillWidth: true
                    visible: NotificationState.serverOk || NotificationState.asks > 0
                    Text {
                        Layout.fillWidth: true
                        text: NotificationState.serverOk ? "Não perturbe" : "Outro programa de notificação está ativo"
                        textFormat: Text.PlainText
                        color: NotificationState.serverOk ? Theme.fg : Theme.gray
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                    }
                    PanelSwitch {
                        visible: NotificationState.serverOk
                        checked: NotificationState.dnd
                        onToggled: NotificationState.toggleDnd()
                    }
                }
                Text {
                    visible: root.refused > 0
                    text: root.refused === 1 ? "1 aviso recusado" : `${root.refused} avisos recusados`
                    textFormat: Text.PlainText
                    color: Theme.gray
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
