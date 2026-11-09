import QtQuick
import Quickshell
import qs.theme

// Big clock and the long date in pt-BR ("domingo, 9 de novembro"). Shared
// with the login screen: no session state.
Column {
    spacing: 4

    // Ticks on the minute: no seconds are shown
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.date.toLocaleString(Theme.locale, "HH:mm")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.lockClockSize
        font.weight: Font.Light
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.date.toLocaleString(Theme.locale, "dddd, d 'de' MMMM")
        color: Theme.text
        opacity: 0.85
        font.family: Theme.font
        font.pixelSize: Theme.lockDateSize
    }
}
