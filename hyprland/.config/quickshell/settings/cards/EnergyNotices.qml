import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.state

// The top of Configurações → Energia: what keeps the choices below from
// holding now. hypridle stopped (the idle times do nothing until it runs);
// hypridle running on the repo's times because hypr-hypridle refused the
// generated file (its "origem" note says "padrao"); the last failure of an
// energy setting (SettingsApply.failed), for a few seconds. Nothing to say:
// `empty`, and the strip hides. The service is only read (systemctl
// is-active, fixed arguments), when the page opens and when the note
// changes.
ColumnLayout {
    id: root

    // Until the check answers, no notice
    property bool running: true
    property string origin: ""
    property string failure: ""

    readonly property var messages: {
        const out = []
        if (failure !== "")
            out.push({ icon: "󰅚", text: failure, color: Theme.red })
        if (!running)
            out.push({ icon: "󰒲", text: "O hypridle está parado: os tempos de inatividade não valem agora",
                       color: Theme.fg4 })
        else if (origin === "padrao" && EnergyApply.written !== "")
            out.push({ icon: "󰀦", text: "Usando os tempos padrão: o arquivo gerado foi recusado", color: Theme.yellow })
        return out
    }
    readonly property bool empty: messages.length === 0

    spacing: 6

    function energyKey(key) {
        return key.startsWith("idle") || key === "lidAction" || key === "conservacao"
    }

    Process {
        id: activeCheck
        command: ["systemctl", "--user", "is-active", "--quiet", "hypridle"]
        running: true
        onExited: code => root.running = code === 0
    }
    FileView {
        readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
        path: runDir !== "" ? `${runDir}/hypridle/origem` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.origin = text().trim()
            activeCheck.running = true
        }
        onLoadFailed: root.origin = ""
    }
    Connections {
        target: SettingsApply
        function onFailed(key, message) {
            if (!root.energyKey(key))
                return
            root.failure = message
            clearTimer.restart()
        }
    }
    Timer {
        id: clearTimer
        interval: 8000
        onTriggered: root.failure = ""
    }

    Repeater {
        model: root.messages

        Rectangle {
            id: notice
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: noticeRow.implicitHeight + 16
            radius: Theme.radius
            color: Theme.alpha(modelData.color, 0.12)

            RowLayout {
                id: noticeRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Text {
                    Layout.alignment: Qt.AlignTop
                    text: notice.modelData.icon
                    color: notice.modelData.color
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    text: notice.modelData.text
                    color: Theme.text
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
            }
        }
    }
}
