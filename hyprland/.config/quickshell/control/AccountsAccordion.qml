import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../settings/ui" as SettingsUi
import "../settings/codecards.js" as Cards

// The control center's GitHub section (state/CodeAccounts reads it): gh's
// accounts of each site with their photo (or letter), "ativa" on the
// active one and Trocar on the others; glab's, read only; how many folders
// have an account of their own, and "editar", which opens that page of the
// settings. Read when the section opens (never when the center opens, and
// never on a timer); closing it lets the reading and the photos go.
// "Esconder nomes" turns the accounts into "conta N" and the photos into
// numbers: the one hidden state of this section and the settings' page,
// not kept. Fixed phrases only; names from outside show as plain text.
ColumnLayout {
    id: root

    // The section open
    required property bool active
    // The monitor of this center (the settings open there)
    property string monitorName: ""
    property real maxListHeight: 240
    // The item the control center's keyboard is on (-1 none)
    property int keyIndex: -1

    readonly property var ghHosts: CodeAccounts.hosts
    readonly property var glabHosts: CodeAccounts.glabHosts
    readonly property bool hide: CodeAccounts.photosHidden
    readonly property int ghCount: ghHosts.reduce((n, h) => n + h.users.length, 0)
    // The order of the accounts on screen (for "conta N")
    function order(host, login) {
        let i = 0
        for (const h of ghHosts.concat(glabHosts)) {
            for (const u of h.users) {
                if (h.host === host && u.login === login)
                    return i
                i++
            }
        }
        return i
    }
    function shownName(host, login) {
        return hide ? `conta ${order(host, login) + 1}` : login
    }

    property bool watching: false
    function watch(on) {
        if (on === watching)
            return
        watching = on
        CodeAccounts.watchPhotos(on)
    }
    // Opened: read and watch. Closed (or gone while open): the reading is
    // let go, unless the settings' page still shows the accounts (both
    // count in CodeAccounts.photoWatchers). The end of a lock reads them
    // again in CodeAccounts, while watched
    function opened() {
        if (watching)
            return
        CodeAccounts.refresh()
        watch(true)
    }
    function closed() {
        watch(false)
        if (CodeAccounts.photoWatchers === 0)
            CodeAccounts.clear()
    }
    onActiveChanged: active ? opened() : closed()
    Component.onCompleted: if (active) opened()
    Component.onDestruction: if (watching) closed()

    function switchTo(host, login) {
        if (active)
            CodeAccounts.switchTo(host, login)
    }
    function openPage() {
        if (!active)
            return
        ShellState.settingsPage = ""
        ShellState.settingsPage = "contas"
        ShellState.toggleByKey("settings", monitorName)
    }

    // ── The control center's keyboard ──
    readonly property var keyItems: {
        const items = [{ kind: "hide" }]
        for (const h of ghHosts) {
            for (const u of h.users) {
                if (!u.active)
                    items.push({ kind: "switch", host: h.host, login: u.login })
            }
        }
        items.push({ kind: "edit" })
        return items
    }
    readonly property int keyCount: keyItems.length
    function keyOn(kind, host, login) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind && (host === undefined || (it.host === host && it.login === login))
    }
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "hide")
            CodeAccounts.photosHidden = !CodeAccounts.photosHidden
        else if (it.kind === "switch")
            switchTo(it.host, it.login)
        else if (it.kind === "edit")
            openPage()
    }

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF02A4)   // nf-md-github, as the grid's button
        title: "GitHub"

        ListButton {
            compact: true
            icon: root.hide ? String.fromCodePoint(0xF0208) : String.fromCodePoint(0xF0209)
            text: root.hide ? "Mostrar nomes" : "Esconder nomes"
            keyFocus: root.keyOn("hide")
            onClicked: CodeAccounts.photosHidden = !CodeAccounts.photosHidden
        }
    }

    // Why there is nothing to show (fixed words only)
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: text !== ""
        text: (CodeAccounts.loading || CodeAccounts.refreshAgain) && root.ghCount === 0 ? "Lendo as contas…"
            : !CodeAccounts.ghAvailable ? "Instale o gh para trocar de conta."
            : CodeAccounts.error !== "" && root.ghCount === 0 ? CodeAccounts.error + "."
            : root.ghCount === 0 ? "Entre pelo terminal, sem rodar setup-git (veja a página)." : ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // ── gh's accounts, a block per site ──
    Repeater {
        model: root.ghHosts

        ColumnLayout {
            id: site
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            ListHeader {
                visible: root.ghHosts.length > 1 || site.modelData.host !== "github.com"
                title: site.modelData.host
            }
            ListBlock {
                maxHeight: root.maxListHeight

                Repeater {
                    model: site.modelData.users

                    ListRow {
                        id: account
                        required property var modelData
                        required property int index
                        divider: index > 0
                        text: root.shownName(site.modelData.host, modelData.login)
                        leading: Component {
                            SettingsUi.AccountAvatar {
                                size: 22
                                hidden: root.hide
                                number: root.order(site.modelData.host, account.modelData.login) + 1
                                letter: Cards.initial(account.modelData.login)
                                photo: CodeAccounts.photoSource(site.modelData.host, account.modelData.login)
                            }
                        }
                        detail: modelData.active ? String.fromCodePoint(0xF012C) + " ativa" : ""
                        detailColor: Theme.green

                        ListButton {
                            visible: !account.modelData.active
                            compact: true
                            text: CodeAccounts.switching ? "Trocando…" : "Trocar"
                            fadeText: CodeAccounts.switching || CodeAccounts.locked
                            keyFocus: root.keyOn("switch", site.modelData.host, account.modelData.login)
                            onClicked: root.switchTo(site.modelData.host, account.modelData.login)
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: CodeAccounts.switchError !== ""
        text: CodeAccounts.switchError
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: root.ghCount > 0
        text: "A conta ativa vale para todos os terminais do gh."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // ── glab's accounts: read only ──
    Repeater {
        model: root.glabHosts

        ColumnLayout {
            id: lab
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            ListHeader {
                title: "GitLab · " + lab.modelData.host
            }
            ListBlock {
                Repeater {
                    model: lab.modelData.users

                    ListRow {
                        id: labAccount
                        required property var modelData
                        required property int index
                        divider: index > 0
                        text: root.shownName(lab.modelData.host, modelData.login)
                        leading: Component {
                            SettingsUi.AccountAvatar {
                                size: 22
                                hidden: root.hide
                                number: root.order(lab.modelData.host, labAccount.modelData.login) + 1
                                letter: Cards.initial(labAccount.modelData.login)
                            }
                        }
                        detail: "só leitura"
                    }
                }
            }
        }
    }

    // ── The folders with an account of their own, and the page ──
    ListBlock {
        Layout.topMargin: 4

        ListRow {
            action: true
            clickable: true
            icon: String.fromCodePoint(0xF1083)   // nf-md-folder_cog
            text: (CodeAccounts.folderCount === 1 ? "1 pasta com conta própria" : `${CodeAccounts.folderCount} pastas com conta própria`) + " · editar"
            keyFocus: root.keyOn("edit")
            onClicked: root.openPage()
        }
    }
}
