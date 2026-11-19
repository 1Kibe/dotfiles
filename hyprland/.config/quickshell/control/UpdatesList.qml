import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The control center's Atualizações section. Each origin, "Sistema"
// (pacman) and "AUR" (paru), has a header (its name on the left, the tool
// and the count on the right) and a block of its own: the first packages,
// "name  old → new" (the versions in the mono font, the new one in green),
// then "e mais N", which opens the rest of that origin, scrolling inside
// the block; with nothing to list, the block holds one line saying why
// (not installed, up to date, could not check). Under them "Atualizar tudo
// no terminal", the main button, which only opens the terminal
// (Updates.openTerminal): nothing is installed from here; and a dim note
// with the last check's time and a small "Verificar agora". Package names
// and versions show as plain text, never as a command or a link.
ColumnLayout {
    id: root

    // The section open
    required property bool active
    // The most an opened origin takes before scrolling inside
    property real maxListHeight: 220
    // The item the control center's keyboard is on (-1 none)
    property int keyIndex: -1

    // "e mais N" opened, per origin; closed again at every opening
    property bool sysAll: false
    property bool aurAll: false
    onActiveChanged: {
        sysAll = false
        aurAll = false
    }

    // How many an origin leaves out of its block (shown or all)
    function hidden(o, all) {
        if (o.state === "missing" || o.count <= 0)
            return 0
        return o.count - Math.min(o.list.length, all ? o.list.length : Lists.UPDATES_SHOWN)
    }
    // "e mais N" opens the rest when there is a rest to show
    function canOpen(o, all) {
        return !all && o.state !== "missing" && o.list.length > Lists.UPDATES_SHOWN
    }

    // ── The control center's keyboard: each "e mais N" that opens, the
    // main button, "Verificar agora" ──
    readonly property var keyItems: {
        const items = []
        if (canOpen(Updates.sys, sysAll))
            items.push({ kind: "moreSys" })
        if (canOpen(Updates.aur, aurAll))
            items.push({ kind: "moreAur" })
        items.push({ kind: "update" })
        items.push({ kind: "check" })
        return items
    }
    readonly property int keyCount: keyItems.length
    function keyOn(kind) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind
    }
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "moreSys")
            sysAll = true
        else if (it.kind === "moreAur")
            aurAll = true
        else if (it.kind === "check")
            Updates.checkNow()
        else if (it.kind === "update")
            openTerminal()
    }
    function openTerminal() {
        if (active && Updates.openTerminal())
            ShellState.close()
    }

    // The one line of a block with nothing to list ("" when it lists)
    function line(o) {
        if (o.state === "missing")
            return o.missing === "fakeroot" ? "checkupdates precisa do fakeroot (base-devel)"
                 : o.missing === "pacman-contrib" ? "checkupdates não instalado (pacman-contrib)"
                 : "paru não instalado"
        if (o.state === "failed")
            return o.count > 0 ? "Não deu para verificar agora" : "Não deu para verificar"
        if (o.count > 0)
            return ""
        if (o.state === "checking")
            return "Verificando…"
        if (o.count === 0)
            return "Em dia"
        return "Ainda não verificado"
    }
    // The header's right side: the tool, and the count once known
    function tool(o, name) {
        return o.state !== "missing" && o.count >= 0 ? `${name} · ${o.count}` : name
    }
    // The note under the button
    readonly property string note: "Abre o Kitty com o paru; a senha é pedida lá. "
        + (Updates.lastCheckAt > 0
           ? `Última verificação: ${Qt.formatTime(new Date(Updates.lastCheckAt), "HH:mm")} · procura de novo a cada 6 h`
           : "Ainda não verificado")

    component Origin: ColumnLayout {
        id: origin
        required property string title
        required property string toolName
        required property var info
        required property bool all
        required property string moreKind
        signal opened()

        readonly property string why: root.line(info)
        readonly property var rows: info.state === "missing" ? [] : all ? info.list : info.list.slice(0, Lists.UPDATES_SHOWN)
        readonly property int more: root.hidden(info, all)
        readonly property bool opens: root.canOpen(info, all)

        Layout.fillWidth: true
        spacing: 4

        // Header: dim, the name left, the tool and the count right
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.topMargin: 4

            Text {
                Layout.fillWidth: true
                text: origin.title
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Medium
            }
            Text {
                text: root.tool(origin.info, origin.toolName)
                textFormat: Text.PlainText
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSizeSmall
            }
        }

        // The block: its rows with a thin line between them
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: blockColumn.implicitHeight
            radius: Theme.radius
            color: Theme.bg

            ColumnLayout {
                id: blockColumn
                width: parent.width
                spacing: 0

                // The packages; the whole origin scrolls inside once opened
                Flickable {
                    id: flick
                    visible: origin.rows.length > 0
                    Layout.fillWidth: true
                    implicitHeight: Math.min(rowsColumn.implicitHeight, root.maxListHeight)
                    contentWidth: width
                    contentHeight: rowsColumn.implicitHeight
                    interactive: rowsColumn.implicitHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: rowsColumn
                        width: flick.width
                        spacing: 0

                        Repeater {
                            model: origin.rows

                            Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 30

                                // A thin line between the rows
                                Rectangle {
                                    visible: index > 0
                                    width: parent.width
                                    height: 1
                                    color: Theme.bg1
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        textFormat: Text.PlainText
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                        color: Theme.fg
                                        font.family: Theme.font
                                        font.pointSize: Theme.fontSize - 1
                                    }
                                    Text {
                                        Layout.maximumWidth: 120
                                        text: modelData.from
                                        textFormat: Text.PlainText
                                        maximumLineCount: 1
                                        elide: Text.ElideLeft
                                        color: Theme.fg4
                                        font.family: Theme.monoFont
                                        font.pointSize: Theme.fontSizeSmall
                                    }
                                    Text {
                                        text: "→"
                                        textFormat: Text.PlainText
                                        color: Theme.fg4
                                        font.family: Theme.monoFont
                                        font.pointSize: Theme.fontSizeSmall
                                    }
                                    Text {
                                        Layout.maximumWidth: 120
                                        text: modelData.to
                                        textFormat: Text.PlainText
                                        maximumLineCount: 1
                                        elide: Text.ElideLeft
                                        color: Theme.green
                                        font.family: Theme.monoFont
                                        font.pointSize: Theme.fontSizeSmall
                                    }
                                }
                            }
                        }
                    }
                }
                // The line saying why there is nothing to list, or that the
                // check failed this time
                Item {
                    visible: origin.why !== ""
                    Layout.fillWidth: true
                    implicitHeight: 30

                    Rectangle {
                        visible: origin.rows.length > 0
                        width: parent.width
                        height: 1
                        color: Theme.bg1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        text: origin.why
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        color: origin.info.state === "failed" ? Theme.red : Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                }
                // "e mais N": opens the rest when there is a rest to show
                Item {
                    visible: origin.more > 0
                    Layout.fillWidth: true
                    implicitHeight: 30

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.bg1
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radius
                        color: moreMouse.containsMouse && origin.opens ? Theme.veil : Theme.clear
                        border.width: root.keyOn(origin.moreKind) ? Theme.focusWidth : 0
                        border.color: Theme.focusRing
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        text: `e mais ${origin.more}`
                        textFormat: Text.PlainText
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        enabled: origin.opens
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: origin.opened()
                    }
                }
            }
        }
    }

    Layout.fillWidth: true
    spacing: 6

    Origin {
        title: "Sistema"
        toolName: "pacman"
        info: Updates.sys
        all: root.sysAll
        moreKind: "moreSys"
        onOpened: root.sysAll = true
    }
    Origin {
        title: "AUR"
        toolName: "paru"
        info: Updates.aur
        all: root.aurAll
        moreKind: "moreAur"
        onOpened: root.aurAll = true
    }

    // The main button: light fill, dark text, the whole width
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 6
        implicitHeight: 32
        radius: Theme.radius
        color: updateMouse.pressed ? Theme.fg4 : Theme.accentLight
        border.width: root.keyOn("update") ? Theme.focusWidth : 0
        border.color: Theme.fg

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: String.fromCodePoint(0xF018D)   // nf-md-console
                textFormat: Text.PlainText
                color: Theme.bgHard
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                text: "Atualizar tudo no terminal"
                textFormat: Text.PlainText
                color: Theme.bgHard
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: updateMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openTerminal()
        }
    }

    // The note, dim, with "Verificar agora" small at its end
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: root.note
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        BarItem {
            Layout.alignment: Qt.AlignTop
            text: Updates.checking ? "Verificando…" : "Verificar agora"
            textColor: Theme.gray
            fontSize: Theme.fontSizeSmall
            keyFocus: root.keyOn("check")
            onClicked: Updates.checkNow()
        }
    }
}
