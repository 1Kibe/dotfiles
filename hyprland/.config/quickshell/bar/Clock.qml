import QtQuick
import Quickshell
import qs.theme
import qs.state
import "baritems.js" as BarItems

// The bar's clock: the date in the chosen format (or none) and the time, in
// 24 h or 12 h, with or without seconds (Configurações → Barra → Relógio);
// "qua 07/11  16:42" by default. The tooltip has the full date. Always
// pt_BR, whatever the system locale is.
BarItem {
    id: root

    clickable: false

    readonly property bool ready: SettingsStore.ready
    readonly property bool h24: ready ? SettingsStore.get("clock24h") === true : true
    readonly property bool seconds: ready ? SettingsStore.get("clockSeconds") === true : false
    readonly property string datePattern: ready ? SettingsStore.get("dateFormat") : "ddd dd/MM"

    // Ticks on the second only when seconds show
    SystemClock {
        id: clock
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    function format(pattern) {
        return clock.date.toLocaleString(Theme.locale, pattern)
    }

    text: BarItems.clockText(datePattern === "" ? "" : BarItems.dateText(format(datePattern)),
                             format(BarItems.timePattern(h24, seconds)))
    readonly property string fullDate: format("dddd, d 'de' MMMM 'de' yyyy")
    tooltip: fullDate
}
