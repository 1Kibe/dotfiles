import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.theme
import qs.state
import "../ui"
import "../codecards.js" as Cards

// Configurações → Contas de código → Perfis: who signs the commits and which
// SSH key pushes (settings/codecards.js, written by SettingsApply to
// ~/.config/git). Each profile shows the photo of its GitHub account (the
// accounts gh read in this opening; one that is not among them shows as
// not found and gets no photo), else its letter. Esconder fotos is the one
// hidden state of the Central and this page. While this card shows, the
// accounts are read once and their photos are fetched; a lock lets them go
// and they are read again when it ends. The SSH keys are only names of
// ~/.ssh: no key file is ever opened. Writes only through SettingsStore.set.
ColumnLayout {
    id: root

    readonly property bool locked: CodeAccounts.locked
    // The text first: a change of another key gives the same text, so the
    // list (and an editor open in it, with what was typed) is not built again
    readonly property string profilesText: SettingsStore.get("codeProfiles") || "[]"
    readonly property var profiles: Cards.list(profilesText)
    // How gh's reading stands, for the accounts' lines
    readonly property string reading: CodeAccounts.loading ? "loading"
                                    : CodeAccounts.error !== "" || !CodeAccounts.ghAvailable ? "failed" : ""
    readonly property bool full: profiles.length >= 8
    // The id being edited, "new" for a new one, "" for none
    property string editing: ""
    property string error: ""
    property var keyNames: []

    spacing: 0

    // Watched while it shows (the settings panel only hides when it closes):
    // read once on showing; hidden, the accounts are let go once nothing
    // else shows them. The end of a lock reads them again in CodeAccounts,
    // while watched
    property bool watching: false
    function watch(on) {
        if (on === watching)
            return
        watching = on
        if (on) {
            CodeAccounts.refresh()
            readKeys()
        }
        CodeAccounts.watchPhotos(on)
    }
    onVisibleChanged: watch(visible)
    Component.onCompleted: watch(visible)
    Component.onDestruction: watch(false)

    function readKeys() {
        if (!keysJob.running)
            keysJob.running = true
    }
    Process {
        id: keysJob
        command: ["timeout", "-k", "2", "5", "bash", "-c", Cards.KEYS_SCRIPT]
        stdout: StdioCollector {
            onStreamFinished: root.keyNames = Cards.keyNames(text)
        }
        stderr: StdioCollector {}
    }

    function edit(id) {
        error = ""
        editing = id
        readKeys()
    }
    function save(draft) {
        const r = Cards.saveProfile(profiles, draft, Cards.list(SettingsStore.get("codeFolders")))
        if (!r.ok) {
            error = r.error
            return
        }
        if (!SettingsStore.set("codeProfiles", r.text)) {
            error = Cards.ERR.store
            return
        }
        error = ""
        editing = ""
    }
    function remove(id) {
        if (SettingsStore.set("codeProfiles", Cards.removeProfile(profiles, id).text))
            editing = ""
        else
            error = Cards.ERR.store
    }

    readonly property Component headerActions: Component {
        Button {
            text: CodeAccounts.photosHidden ? "Mostrar fotos" : "Esconder fotos"
            icon: CodeAccounts.photosHidden ? "\u{f0208}" : "\u{f0209}"
            onClicked: CodeAccounts.photosHidden = !CodeAccounts.photosHidden
        }
    }

    Repeater {
        model: root.profiles

        ColumnLayout {
            id: entry
            required property var modelData
            required property int index
            readonly property bool open: root.editing === modelData.id
            readonly property bool read: Cards.accountRead(modelData, CodeAccounts.hosts)
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                spacing: 10

                AccountAvatar {
                    size: 28
                    hidden: CodeAccounts.photosHidden
                    number: entry.index + 1
                    letter: Cards.initial(entry.modelData.label)
                    photo: entry.read ? CodeAccounts.photoSource("github.com", Cards.ghLogin(entry.modelData)) : ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: entry.modelData.label
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Cards.accountText(entry.modelData, CodeAccounts.hosts, entry.index, CodeAccounts.photosHidden, root.reading)
                              + " · " + entry.modelData.key
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.fg4
                        font.family: Theme.monoFont
                        font.pointSize: Theme.fontSize - 1
                    }
                }
                Button {
                    text: entry.open ? "Fechar" : "Editar"
                    enabled: !root.locked
                    onClicked: root.edit(entry.open ? "" : entry.modelData.id)
                }
            }

            Loader {
                Layout.fillWidth: true
                active: entry.open
                visible: active
                sourceComponent: CodeProfileEditor {
                    draft: entry.modelData
                    keyOptions: Cards.keyOptions(root.keyNames, entry.modelData.key)
                    ghOptions: Cards.ghOptions(CodeAccounts.hosts, entry.modelData.ghAccount)
                    locked: root.locked
                    error: root.error
                    onSave: d => root.save(d)
                    onCancel: root.edit("")
                    onRemove: root.remove(entry.modelData.id)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                implicitHeight: 1
                color: Theme.bg1
            }
        }
    }

    OptionRow {
        visible: root.editing !== "new"
        label: "Adicionar perfil"
        desc: root.full ? "No máximo 8 perfis" : "Nome e e-mail do commit, chave SSH e, se quiser, a conta do GitHub"
        Button {
            text: "Adicionar"
            icon: "\u{f0415}"
            enabled: !root.locked && !root.full
            opacity: enabled ? 1 : 0.5
            onClicked: root.edit("new")
        }
    }
    Loader {
        Layout.fillWidth: true
        active: root.editing === "new"
        visible: active
        sourceComponent: CodeProfileEditor {
            isNew: true
            draft: ({ id: "", label: "", name: "", email: "", key: "", ghAccount: "" })
            keyOptions: Cards.keyOptions(root.keyNames, "")
            ghOptions: Cards.ghOptions(CodeAccounts.hosts, "")
            locked: root.locked
            error: root.error
            onSave: d => root.save(d)
            onCancel: root.edit("")
        }
    }

    OptionRow {
        divider: true
        label: "Fotos dos perfis"
        desc: "Mostra a foto pública da conta do GitHub"
        Toggle {
            checked: SettingsStore.get("codePhotos") === true
            enabled: !root.locked
            opacity: enabled ? 1 : 0.5
            onToggled: v => SettingsStore.set("codePhotos", v)
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        text: "O e-mail vira autor dos commits. Em repo público, use o e-mail noreply do GitHub. A foto vem da conta do GitHub ligada ao perfil."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
