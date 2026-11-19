import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The control center's Atualizações section: by origin, "Sistema"
// (pacman) and "AUR", each with its count and its first packages
// ("name old → new") and "e mais N", or why there is none; "Verificar
// agora"; and "Atualizar tudo no terminal", which only opens the terminal
// (Updates.openTerminal): nothing is installed from here. Package names
// and versions show as plain text, never as a command or a link.
ColumnLayout {
    id: root

    // The section open
    required property bool active
    // The item the control center's keyboard is on (-1 none)
    property int keyIndex: -1

    // ── The control center's keyboard: "Verificar agora", "Atualizar" ──
    readonly property var keyItems: [{ kind: "check" }, { kind: "update" }]
    readonly property int keyCount: keyItems.length
    function keyOn(kind) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind
    }
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "check")
            Updates.checkNow()
        else if (it.kind === "update")
            openTerminal()
    }
    function openTerminal() {
        if (active && Updates.openTerminal())
            ShellState.close()
    }

    // What an origin says under its title (fixed words only)
    function line(o) {
        if (o.state === "missing")
            return o.missing === "fakeroot" ? "checkupdates precisa do fakeroot (base-devel)"
                 : o.missing === "pacman-contrib" ? "checkupdates não instalado (pacman-contrib)"
                 : "paru não instalado"
        if (o.state === "checking" && o.count < 0)
            return "Verificando…"
        if (o.state === "failed")
            return o.count > 0 ? `Não deu para verificar agora (antes: ${o.count})` : "Não deu para verificar"
        if (o.count < 0)
            return "Ainda não verificado"
        if (o.count === 0)
            return "Em dia"
        return o.count === 1 ? "1 atualização" : `${o.count} atualizações`
    }

    component Origin: ColumnLayout {
        id: origin
        required property string title
        required property var data

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 6

            Text {
                text: origin.title
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.line(origin.data)
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                color: origin.data.count > 0 ? Theme.yellow : Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
        }
        Repeater {
            model: origin.data.state === "missing" ? [] : origin.data.list.slice(0, Lists.UPDATES_SHOWN)

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                Text {
                    Layout.maximumWidth: 160
                    text: `${modelData.from} → ${modelData.to}`
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    elide: Text.ElideLeft
                    color: Theme.gray
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
            }
        }
        Text {
            Layout.leftMargin: 16
            // Those not shown: past the first ones, and the lines too long to show
            readonly property int more: origin.data.state === "missing" || origin.data.count < 0 ? 0
                                      : origin.data.count - Math.min(origin.data.list.length, Lists.UPDATES_SHOWN)
            visible: more > 0
            text: `e mais ${more}`
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }

    Layout.fillWidth: true
    spacing: 2

    Origin {
        title: "Sistema"
        data: Updates.sys
    }
    Origin {
        title: "AUR"
        data: Updates.aur
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.bg2
    }

    PanelRow {
        icon: "󰑓"
        text: Updates.checking ? "Verificando…" : "Verificar agora"
        keyFocus: root.keyOn("check")
        onClicked: Updates.checkNow()
    }
    PanelRow {
        icon: String.fromCodePoint(0xF01DA)   // nf-md-download
        text: "Atualizar tudo no terminal"
        keyFocus: root.keyOn("update")
        onClicked: root.openTerminal()
    }
}
