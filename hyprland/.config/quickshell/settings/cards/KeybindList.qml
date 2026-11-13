import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import "../ui"
import "../keybinds.js" as Keybinds

// Configurações → Atalhos: the keybinds Hyprland has in use and the touchpad
// gestures, read from `hypr-atalhos --json` (the same list as Super+F1 and
// the README) each time the page opens, by its full path and with a time
// limit. The list is checked (settings/keybinds.js) and only shown, as plain
// text: nothing here is saved or changed. A search above narrows it.
ColumnLayout {
    id: root

    readonly property string script: `${Quickshell.env("HOME")}/.local/bin/hypr-atalhos`
    // "" reading, "ok", "fail"
    property string status: ""
    property var groups: []
    property string query: ""
    readonly property var shown: Keybinds.filter(groups, query)

    spacing: 10

    function read() {
        if (job.running)
            return
        status = ""
        job.running = true
        limit.restart()
    }
    Component.onCompleted: read()
    onVisibleChanged: if (visible) read()

    Process {
        id: job
        command: [root.script, "--json"]
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            limit.stop()
            const r = code === 0 ? Keybinds.parse(out.text) : { ok: false, groups: [] }
            root.groups = r.groups
            root.status = r.ok ? "ok" : "fail"
        }
        onRunningChanged: {
            // A command that cannot start never sends exited
            if (!running && root.status === "")
                Qt.callLater(() => {
                    if (root.status === "") {
                        limit.stop()
                        root.status = "fail"
                    }
                })
        }
    }
    // Five seconds at most: then it is stopped and the page says so
    Timer {
        id: limit
        interval: 5000
        onTriggered: {
            job.running = false
            root.groups = []
            root.status = "fail"
        }
    }

    Field {
        id: search
        Layout.fillWidth: true
        placeholder: "󰍉  Buscar atalho"
        input.onTextChanged: root.query = search.input.text
    }

    Text {
        visible: root.status !== "ok" || root.shown.length === 0
        Layout.fillWidth: true
        text: root.status === "" ? "Lendo os atalhos…"
            : root.status === "fail" ? "Não deu para ler os atalhos"
            : "Nenhum atalho com essa busca"
        textFormat: Text.PlainText
        color: Theme.fg4
        wrapMode: Text.WordWrap
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Repeater {
        model: root.status === "ok" ? root.shown : []

        ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.topMargin: 6
                text: group.modelData.name
                textFormat: Text.PlainText
                color: Theme.accentLight
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.DemiBold
            }
            Repeater {
                model: group.modelData.items

                RowLayout {
                    id: line
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12

                    Flow {
                        Layout.preferredWidth: 230
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Repeater {
                            model: line.modelData.keys
                            Rectangle {
                                id: chip
                                required property string modelData
                                implicitWidth: keyText.implicitWidth + 12
                                implicitHeight: keyText.implicitHeight + 6
                                width: Math.min(implicitWidth, 230)
                                radius: Math.max(2, Theme.radius - 3)
                                color: Theme.bg1
                                border.width: 1
                                border.color: Theme.bg2
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, 218)
                                    text: chip.modelData
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.monoFont
                                    font.pointSize: Theme.fontSize - 2
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: line.modelData.text
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
