import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.state
import "../ui"

// Bloqueio e login → Segurança, read only: the limits of wrong attempts
// (faillock.conf, read the way the lock reads them) and this user's recent
// ones, the fallback lock, what the login screen remembers, and where the
// idle times are (Energia).
ColumnLayout {
    id: root

    spacing: 8

    property int deny: 3
    property int interval: 900
    property int unlockTime: 600
    property int recent: 0

    Process {
        running: true
        command: ["sh", "-c", LockState.faillockScript, "sh", LockState.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                const conf = (lines[0] || "").split(" ")
                root.deny = parseInt(conf[1]) || 3
                root.interval = parseInt(conf[2]) || 900
                root.unlockTime = parseInt(conf[3]) || 600
                const now = parseInt(conf[4]) || Math.floor(Date.now() / 1000)
                let count = 0
                for (const line of lines) {
                    const m = line.match(/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\s.*\sV\s*$/)
                    if (!m)
                        continue
                    const t = Math.floor(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() / 1000)
                    if (now - t <= root.interval)
                        count++
                }
                root.recent = count
            }
        }
    }

    component Line: RowLayout {
        property string icon
        property string title
        property string detail
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignTop
            text: parent.icon
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize + 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: parent.parent.title
                color: Theme.text
                wrapMode: Text.WordWrap
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                Layout.fillWidth: true
                text: parent.parent.detail
                color: Theme.gray
                wrapMode: Text.WordWrap
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
            }
        }
    }

    Line {
        icon: "󰌾"
        title: `${root.deny} senhas erradas em ${Math.round(root.interval / 60)} min travam por ${Math.round(root.unlockTime / 60)} min`
        detail: root.recent === 0 ? "Nenhum erro recente" : root.recent === 1 ? "1 erro recente" : `${root.recent} erros recentes`
    }
    Line {
        icon: "󰒃"
        title: "Bloqueio reserva"
        detail: "Se o shell não responder, o hyprlock trava a tela"
    }
    Line {
        icon: "󰍂"
        title: "Login"
        detail: "Lembra o último usuário e a sessão"
    }
    Button {
        text: "Tempos de inatividade (Energia)"
        icon: "󰒲"
        onClicked: {
            ShellState.settingsPage = ""
            ShellState.settingsPage = "energia"
        }
    }
}
