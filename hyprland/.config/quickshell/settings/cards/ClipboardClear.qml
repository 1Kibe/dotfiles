import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"

// Captura e clipboard → Histórico: clear the clipboard history. The first
// click arms the button ("Confirmar?", red, 3 s); a second click in that
// time clears it. The pinned items are kept (their own file).
ColumnLayout {
    id: root

    spacing: 6

    property bool armed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Apaga o histórico do clipboard. Os itens fixados ficam."
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    Button {
        text: root.armed ? "Confirmar?" : "Limpar histórico"
        icon: "󰆴"
        danger: root.armed
        onClicked: {
            if (!root.armed) {
                root.armed = true
                disarm.restart()
                return
            }
            disarm.stop()
            root.armed = false
            ClipboardStore.wipe()
            done.restart()
        }
    }
    Text {
        id: doneText
        text: "Histórico limpo"
        color: Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
        opacity: done.running ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(Theme.animFast) }
        }
    }
    Timer {
        id: done
        interval: 2500
    }
}
