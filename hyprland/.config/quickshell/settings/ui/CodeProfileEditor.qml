import QtQuick
import QtQuick.Layouts
import qs.theme

// The editor of one profile in Configurações → Contas de código → Perfis
// (settings/cards/CodeProfiles; here because the cards load by address):
// its five fields, read when Pronto is pressed (typed text counts even
// before Enter). Nothing is kept until the card's saveProfile accepts it;
// a refusal shows its fixed phrase here.
ColumnLayout {
    id: root

    property var draft: ({})
    property var keyOptions: []
    property var ghOptions: []
    property bool isNew: false
    property bool locked: false
    property string error: ""
    signal save(var draft)
    signal cancel()
    signal remove()

    property string keyValue: draft.key || ""
    property string ghValue: draft.ghAccount || ""
    property bool armed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }

    spacing: 0

    OptionRow {
        divider: true
        label: "Nome do perfil"
        desc: "Só para a tela"
        Field {
            id: labelField
            value: root.draft.label || ""
            placeholder: "Pessoal"
        }
    }
    OptionRow {
        divider: true
        label: "Nome no commit"
        Field {
            id: nameField
            value: root.draft.name || ""
            placeholder: "Seu nome"
        }
    }
    OptionRow {
        divider: true
        label: "E-mail no commit"
        Field {
            id: emailField
            value: root.draft.email || ""
            placeholder: "noreply do GitHub"
            mono: true
        }
    }
    OptionRow {
        divider: true
        label: "Chave SSH"
        desc: root.keyOptions.length === 0 ? "Nenhuma chave em ~/.ssh (arquivo do usuário, 600)" : "Arquivo de ~/.ssh"
        Dropdown {
            options: root.keyOptions
            value: root.keyValue
            enabled: !root.locked && root.keyOptions.length > 0
            opacity: enabled ? 1 : 0.5
            onPicked: v => root.keyValue = v
        }
    }
    OptionRow {
        divider: true
        label: "Conta do GitHub"
        desc: "De onde vem a foto; não vai para o git"
        Dropdown {
            options: root.ghOptions
            value: root.ghValue
            enabled: !root.locked
            opacity: enabled ? 1 : 0.5
            onPicked: v => root.ghValue = v
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

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 4
        spacing: 6
        // Two clicks: the first arms it for 3 s
        Button {
            text: root.armed ? "Confirmar?" : "Remover"
            icon: "\u{f0a7a}"
            danger: root.armed
            destructive: true
            visible: !root.isNew
            enabled: !root.locked
            onClicked: {
                if (!root.armed) {
                    root.armed = true
                    disarm.restart()
                    return
                }
                root.armed = false
                root.remove()
            }
        }
        Item { Layout.fillWidth: true }
        Button {
            text: "Cancelar"
            onClicked: root.cancel()
        }
        Button {
            text: "Pronto"
            enabled: !root.locked
            onClicked: root.save({ id: root.draft.id || "", label: labelField.input.text, name: nameField.input.text,
                                   email: emailField.input.text, key: root.keyValue, ghAccount: root.ghValue })
        }
    }
}
