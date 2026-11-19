import QtQuick
import Quickshell
import "../control/lists.js" as Lists

// One level of a tray app's menu (dbusmenu, through QsMenuOpener), read
// only while `menu` is set. The entries come later than the opener (the
// app sends its layout) and can change; the copy here follows them at most
// every 250 ms, the first TRAY_MENU_MAX entries only. Each entry: { entry
// (the QsMenuEntry, for triggered() and its submenu), text (cleaned),
// enabled, separator, children, check ("" none, "check", "radio"), checked }.
// Only text and state are kept: no icon from the app.
Item {
    id: root

    // A QsMenuHandle (an item's menu, or an entry with children); null
    // stops reading
    property var menu: null
    readonly property var entries: copy
    property var copy: []

    QsMenuOpener {
        id: opener
        menu: root.menu
    }
    Connections {
        target: opener
        function onChildrenChanged() {
            root.schedule()
        }
    }
    onMenuChanged: {
        copy = []
        schedule()
    }

    property bool again: false
    function schedule() {
        if (wait.running) {
            again = true
            return
        }
        take()
        wait.restart()
    }
    function take() {
        const list = root.menu ? Lists.toList(opener.children.values).slice(0, Lists.TRAY_MENU_MAX) : []
        copy = list.map(e => ({
            entry: e,
            text: Lists.trayText(e.text),
            enabled: e.enabled === true,
            separator: e.isSeparator === true,
            children: e.hasChildren === true,
            check: e.buttonType === QsMenuButtonType.CheckBox ? "check" : e.buttonType === QsMenuButtonType.RadioButton ? "radio" : "",
            checked: e.checkState === Qt.Checked
        }))
    }
    Timer {
        id: wait
        interval: 250
        onTriggered: {
            if (root.again) {
                root.again = false
                root.take()
                wait.restart()
            }
        }
    }
}
