import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../schema.js" as Schema

// Configurações → Sobre → Suas configurações: where the choices are kept,
// Exportar (the choices that are not this machine's go to the repo's
// defaults.json, state/AboutState: never staged, committed or pushed; the
// git diff is for you to review) and Restaurar tudo (state/SettingsStore: a
// copy first, then every choice of this machine goes, with Desfazer for half
// a minute). Both ask before acting, Cancelar first; the buttons answer the
// mouse only, so no key confirms them.
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    property var exportPlan: null
    property bool askRestore: false
    property bool restored: false
    readonly property var machineKeys: Object.keys(SettingsStore.user || {})

    function labels(keys) {
        const names = keys.map(k => Schema.KEYS[k] ? Schema.KEYS[k].label : k)
        return names.length > 6 ? names.slice(0, 6).join(", ") + ` e mais ${names.length - 6}` : names.join(", ")
    }

    spacing: 0
    onVisibleChanged: if (!visible) {
        exportPlan = null
        askRestore = false
    }

    component Note: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    OptionRow {
        label: "Onde ficam"
        desc: "Só as escolhas desta máquina; o resto vem do repo"
        Text {
            text: "~/.config/dotfiles/settings.json"
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.monoFont
            font.pointSize: Theme.fontSize - 2
        }
    }

    // ── Exportar ──
    OptionRow {
        divider: true
        label: "Exportar para o repo"
        desc: AboutState.repoOk ? "Leva as suas escolhas (menos as desta máquina) para o defaults.json do repo"
                                : "Repo não encontrado, ou com dono ou permissão errados"
        Button {
            text: "Exportar…"
            icon: "󰈝"
            enabled: AboutState.repoOk && !AboutState.exporting && !root.locked && root.exportPlan === null
            opacity: enabled ? 1 : 0.5
            onClicked: root.exportPlan = AboutState.plan()
        }
    }
    ColumnLayout {
        visible: root.exportPlan !== null
        Layout.fillWidth: true
        spacing: 6
        Note {
            text: root.exportPlan === null ? ""
                : root.exportPlan.changed.length === 0 ? "Nada muda no defaults.json do repo."
                : `Mudam no defaults.json: ${root.labels(root.exportPlan.changed)}.`
                  + (root.exportPlan.skipped.length > 0
                     ? ` Ficam como no repo (pasta pessoal ou valor inválido): ${root.labels(root.exportPlan.skipped)}.` : "")
                  + " Nada vai para o git sozinho."
        }
        RowLayout {
            Layout.leftMargin: 8
            spacing: 8
            Button {
                text: "Cancelar"
                onClicked: root.exportPlan = null
            }
            Button {
                text: "Exportar"
                enabled: root.exportPlan !== null && root.exportPlan.changed.length > 0
                opacity: enabled ? 1 : 0.5
                onClicked: {
                    root.exportPlan = null
                    AboutState.exportNow()
                }
            }
        }
    }
    Note {
        visible: AboutState.exportMessage !== ""
        text: AboutState.exportMessage
        color: Theme.text
    }

    // ── Restaurar tudo ──
    OptionRow {
        divider: true
        label: "Restaurar tudo"
        desc: "Apaga as escolhas desta máquina e volta aos padrões do repo"
        Button {
            text: "Restaurar tudo…"
            icon: "󰑓"
            destructive: true
            enabled: SettingsStore.ready && !root.locked && !root.askRestore && root.machineKeys.length > 0
            opacity: enabled ? 1 : 0.5
            onClicked: root.askRestore = true
        }
    }
    ColumnLayout {
        visible: root.askRestore
        Layout.fillWidth: true
        spacing: 6
        Note {
            text: `Somem ${root.machineKeys.length} ${root.machineKeys.length === 1 ? "escolha" : "escolhas"}: `
                  + `${root.labels(root.machineKeys)}. Antes fica uma cópia (settings.json.bak-…), e dá para desfazer `
                  + `por ${SettingsStore.undoSeconds} segundos. O teclado do login e os apps padrão do sistema não mudam.`
        }
        RowLayout {
            Layout.leftMargin: 8
            spacing: 8
            Button {
                text: "Cancelar"
                onClicked: root.askRestore = false
            }
            Button {
                text: "Restaurar"
                destructive: true
                onClicked: {
                    root.askRestore = false
                    SettingsStore.restoreAll(ok => root.restored = ok)
                }
            }
        }
    }
    RowLayout {
        visible: root.restored && SettingsStore.undoUser !== null
        Layout.leftMargin: 8
        spacing: 8
        Note {
            Layout.fillWidth: false
            text: "Restaurado."
            color: Theme.text
        }
        Button {
            text: "Desfazer"
            icon: "󰕌"
            onClicked: {
                SettingsStore.undoRestore()
                root.restored = false
            }
        }
    }
    Note {
        visible: SettingsStore.loadError !== ""
        text: SettingsStore.loadError
        color: Theme.red
    }
}
