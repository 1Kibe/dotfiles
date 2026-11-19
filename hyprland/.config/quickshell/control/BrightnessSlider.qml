import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar

// The control center's brightness (the internal screen): slider and
// percent, on the keys' curve. Not there without a backlight.
RowLayout {
    id: root

    property bool keyFocus: false

    // ←/→: 5% per step, never below 1%
    function step(steps) {
        Brightness.set(Math.max(1, Math.min(100, Brightness.percent + 5 * steps)))
    }

    visible: Brightness.available
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: 6

    // nf-md-brightness_6
    BarItem {
        text: String.fromCodePoint(0xF00DF)
        clickable: false
    }
    PanelSlider {
        Layout.fillWidth: true
        value: Brightness.percent / 100
        keyFocus: root.keyFocus
        onMoved: v => Brightness.set(Math.max(1, Math.round(v * 100)))
    }
    Text {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText
        text: `${Brightness.percent}%`
        color: Theme.text
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
    // Lines up with the volume's mixer arrow
    Item {
        implicitWidth: Theme.itemHeight
    }
}
