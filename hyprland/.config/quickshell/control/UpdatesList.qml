import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "lists.js" as Lists

// The control center's Atualizações section: the header with the state;
// each origin, "Sistema" (pacman, with the last check's time on its
// header) and "AUR" (paru), in a block of its own (UpdatesOrigin); under
// them two buttons side by side: "Verificar agora" and "Atualizar tudo no
// terminal", the main one, which only opens the terminal
// (Updates.openTerminal): nothing is installed from here.
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

    // ── The control center's keyboard: each "e mais N" that opens, then
    // the two buttons, left to right ──
    readonly property var keyItems: {
        const items = []
        if (Lists.updatesCanOpen(Updates.sys, sysAll))
            items.push({ kind: "moreSys" })
        if (Lists.updatesCanOpen(Updates.aur, aurAll))
            items.push({ kind: "moreAur" })
        items.push({ kind: "check" })
        items.push({ kind: "update" })
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

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF06B0)   // nf-md-update, as the grid's button
        title: "Atualizações"
        detail: Updates.summary.text
    }
    UpdatesOrigin {
        title: "Sistema"
        toolName: "pacman"
        info: Updates.sys
        all: root.sysAll
        time: Updates.lastCheckAt > 0 ? Qt.formatTime(new Date(Updates.lastCheckAt), "HH:mm") : ""
        maxHeight: root.maxListHeight
        moreFocus: root.keyOn("moreSys")
        onOpened: root.sysAll = true
    }
    UpdatesOrigin {
        title: "AUR"
        toolName: "paru"
        info: Updates.aur
        all: root.aurAll
        maxHeight: root.maxListHeight
        moreFocus: root.keyOn("moreAur")
        onOpened: root.aurAll = true
    }

    // The two buttons: the check, and the main one (the terminal; the
    // password is asked there)
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 6

        ListButton {
            text: Updates.checking ? "Verificando…" : "Verificar agora"
            keyFocus: root.keyOn("check")
            onClicked: Updates.checkNow()
        }
        ListButton {
            Layout.fillWidth: true
            primary: true
            icon: String.fromCodePoint(0xF018D)   // nf-md-console
            text: "Atualizar tudo no terminal"
            keyFocus: root.keyOn("update")
            onClicked: root.openTerminal()
        }
    }
}
