import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../apps.js" as Apps

// Configurações → Apps padrão: one row per kind of file or link, with the apps
// this machine has that open it (state/AppsState). The row shows what the
// system uses now (xdg-mime), not what was saved; a choice goes to the system
// only from here. Documentos, Planilhas and the other optional rows show only
// when some installed app opens them. Terminal and Arquivos are the apps of
// the Super+Enter and Super+E keybinds; if the chosen one does not open,
// going back to the default is the way out. Each app says where it comes
// from (the system, your folder, Flatpak), and when your copy hides the
// system's.
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted

    spacing: 0
    Component.onCompleted: AppsState.refresh()
    onVisibleChanged: if (visible) AppsState.refresh()

    Repeater {
        model: AppsState.rows()

        OptionRow {
            id: row
            required property var modelData
            required property int index
            readonly property bool shortcut: modelData.key === "appTerminal" || modelData.key === "appFiles"
            readonly property var choices: {
                const list = Apps.candidates(modelData.key, AppsState.apps)
                                 .map(a => ({ value: a.id, label: `${a.name} · ${Apps.describe(a)}` }))
                if (shortcut)
                    list.unshift({ value: "", label: modelData.key === "appTerminal" ? "Padrão (Kitty)" : "Padrão (Thunar)" })
                return list
            }
            readonly property string value: shortcut ? String(SettingsStore.get(modelData.key) || "")
                                                     : (AppsState.current[modelData.key] || "")

            divider: index > 0
            label: modelData.label
            desc: shortcut ? "Vale para o atalho " + (modelData.key === "appTerminal" ? "Super+Enter" : "Super+E")
                             + ". Se o escolhido não abrir, volte para o padrão"
                           : (value === "" ? "O sistema não tem um padrão" : "")
            Dropdown {
                options: row.choices
                value: row.value
                rows: 8
                enabled: !root.locked && !AppsState.busy && row.choices.length > 0
                opacity: enabled ? 1 : 0.5
                onPicked: v => {
                    if (v !== row.value)
                        AppsState.apply(row.modelData.key, v)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        text: "A lista de atalhos (Super+F1), as regras de janela e o btop continuam no Kitty."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
    Text {
        visible: AppsState.message !== ""
        Layout.fillWidth: true
        Layout.margins: 8
        text: AppsState.message
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
