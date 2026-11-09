import QtQuick
import Quickshell
import qs.theme

// "qua 07/11  16:42"; the tooltip has the full date. Always pt_BR.
BarItem {
    id: root

    clickable: false

    // Ticks on the minute: no seconds are shown
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Theme.locale (pt_BR), whatever the system locale is
    function format(pattern) {
        return clock.date.toLocaleString(Theme.locale, pattern)
    }

    // pt_BR abbreviates "qua." with a dot; the login screen shows "qua"
    text: `${format("ddd").replace(".", "").toLowerCase()} ${format("dd/MM")}  ${format("HH:mm")}`
    readonly property string fullDate: format("dddd, d 'de' MMMM 'de' yyyy")
    tooltip: fullDate
}
