import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import "../notifications/calendar.js" as Cal

// The month in the clock's panel: its name with arrows to the month before
// and after (a click on the name goes back to today's), the days' initials
// from the locale's first day and six weeks of days; today with a ring,
// the neighbour months' days in grey. Only the days: no events. Today
// comes from the system clock (once a minute).
ColumnLayout {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property var today: ({ year: clock.date.getFullYear(), month: clock.date.getMonth(), day: clock.date.getDate() })
    property int year: today.year
    property int month: today.month
    readonly property int firstDay: Theme.locale.firstDayOfWeek % 7
    readonly property var grid: Cal.monthGrid(year, month, firstDay, today)

    function go(delta) {
        const m = Cal.shift(year, month, delta)
        year = m.year
        month = m.month
    }
    function backToToday() {
        year = today.year
        month = today.month
    }

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: String.fromCodePoint(0xF0141)   // nf-md-chevron_left
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            TapHandler { onTapped: root.go(-1) }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Cal.monthTitle(root.year, root.month)
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize
            font.weight: Font.Medium
            TapHandler { onTapped: root.backToToday() }
        }
        Text {
            text: String.fromCodePoint(0xF0142)   // nf-md-chevron_right
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            TapHandler { onTapped: root.go(1) }
        }
    }

    Grid {
        columns: 7
        Repeater {
            model: Cal.weekDays(root.firstDay)
            Text {
                required property string modelData
                width: Theme.calendarCell
                height: Theme.calendarCell * 0.7
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                textFormat: Text.PlainText
                color: Theme.gray
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSizeSmall
            }
        }
        Repeater {
            model: root.grid
            Item {
                required property var modelData
                width: Theme.calendarCell
                height: Theme.calendarCell
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: width
                    radius: width / 2
                    color: Theme.clear
                    border.width: parent.modelData.isToday ? 1 : 0
                    border.color: Theme.accentLight
                }
                Text {
                    anchors.centerIn: parent
                    text: String(parent.modelData.day)
                    textFormat: Text.PlainText
                    color: parent.modelData.inMonth ? Theme.fg : Theme.gray
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
            }
        }
    }
}
