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
// only while it really shows: never locked, never under the overview.
AttachedPanel {
    id: root

    required property string monitorName
    centered: true
    panelWidth: Theme.clockPanelWidth

    readonly property bool showing: visible && open && !NotificationState.locked && !OverviewState.open
    onShowingChanged: {
        if (showing) {
            NotificationState.markAllRead()
            // The cards on screen are in the list now
            NotificationState.clearScreen()
        }
    }
    // Arrivals while it shows are read too
    Connections {
        target: NotificationState
        function onArrived() {
            if (root.showing)
                NotificationState.markAllRead()
        }
    }

    readonly property int refused: (NotificationState.dropped.text || 0) + (NotificationState.dropped.rate || 0)
                                   + (NotificationState.dropped.cap || 0)

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 8
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
                    TapHandler { onTapped: NotificationState.clearAll() }
                }
            }
            NotificationList {
                Layout.fillWidth: true
                maxHeight: 360
            }
            RowLayout {
                Layout.fillWidth: true
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
