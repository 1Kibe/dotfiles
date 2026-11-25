import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import "../ui"
import "../codecards.js" as Cards
import "../gitaccounts.js" as Git

// Configurações → Contas de código → Pastas: inside each folder (and all
// below it) its profile signs the commits and pushes with its key (an
// includeIf in ~/.config/git/contas.conf). A folder must be inside the
// home and outside ~/.ssh, ~/.config and ~/.gnupg (settings/codecards.js
// says why in a fixed phrase). A folder whose profile was removed stays,
// with no includeIf, until it gets another one. Writes only through
// SettingsStore.set.
ColumnLayout {
    id: root

    readonly property bool locked: CodeAccounts.locked
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property var profiles: Cards.list(SettingsStore.get("codeProfiles"))
    readonly property var folders: Cards.list(SettingsStore.get("codeFolders"))
    readonly property var nestedPaths: Git.nested(folders.filter(f => profiles.some(p => p.id === f.profile)))
    readonly property bool full: folders.length >= 32
    property string addProfile: ""
    property string error: ""

    spacing: 0

    function store(r) {
        if (!r.ok) {
            error = r.error
            return false
        }
        if (!SettingsStore.set("codeFolders", r.text)) {
            error = Cards.ERR.store
            return false
        }
        error = ""
        return true
    }
    function folderDesc(f) {
        if (!profiles.some(p => p.id === f.profile))
            return "Perfil removido: aqui vale a conta ativa"
        if (nestedPaths.includes(f.path))
            return "Dentro de outra pasta com outro perfil: aqui vale este"
        return ""
    }

    Text {
        visible: root.folders.length === 0
        Layout.fillWidth: true
        Layout.margins: 8
        text: "Nenhuma pasta com conta própria. Fora das pastas vale a conta ativa."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Repeater {
        model: root.folders
        OptionRow {
            id: line
            required property var modelData
            required property int index
            divider: index > 0
            icon: "\u{f024b}"
            label: modelData.path
            desc: root.folderDesc(modelData)
            RowLayout {
                spacing: 6
                Dropdown {
                    options: Cards.profileOptions(root.profiles)
                    value: line.modelData.profile
                    enabled: !root.locked && root.profiles.length > 0
                    opacity: enabled ? 1 : 0.5
                    onPicked: v => root.store(Cards.setFolderProfile(root.folders, root.profiles, line.modelData.path, v))
                }
                Button {
                    text: "Tirar"
                    enabled: !root.locked
                    onClicked: root.store(Cards.removeFolder(root.folders, line.modelData.path))
                }
            }
        }
    }

    OptionRow {
        divider: root.folders.length > 0
        icon: "\u{f0415}"
        label: "Adicionar pasta"
        desc: root.profiles.length === 0 ? "Crie um perfil antes" : root.full ? "No máximo 32 pastas" : "A pasta e tudo abaixo dela"
    }
    RowLayout {
        id: addRow
        readonly property bool can: !root.locked && root.profiles.length > 0 && !root.full
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 6
        spacing: 6
        Field {
            id: pathField
            Layout.fillWidth: true
            mono: true
            placeholder: "~/projetos"
            invalid: root.error !== ""
            enabled: addRow.can
            opacity: enabled ? 1 : 0.5
        }
        Dropdown {
            options: Cards.profileOptions(root.profiles)
            value: root.addProfile !== "" ? root.addProfile : (root.profiles.length > 0 ? root.profiles[0].id : "")
            enabled: addRow.can
            opacity: enabled ? 1 : 0.5
            onPicked: v => root.addProfile = v
        }
        Button {
            text: "Adicionar"
            enabled: addRow.can
            opacity: enabled ? 1 : 0.5
            onClicked: {
                const id = root.addProfile !== "" ? root.addProfile : (root.profiles.length > 0 ? root.profiles[0].id : "")
                if (root.store(Cards.addFolder(root.folders, root.profiles, pathField.input.text, id, root.home)))
                    pathField.input.text = ""
            }
        }
    }

    Text {
        visible: root.error !== ""
        Layout.fillWidth: true
        Layout.margins: 8
        text: root.error
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        text: "A pasta troca a identidade e a chave SSH. Em HTTPS vale a conta ativa do gh."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
