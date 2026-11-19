import QtQuick
import Quickshell
import "../control/lists.js" as Lists

// One level of a tray app's menu (dbusmenu, through QsMenuOpener), read
// only while `menu` is set. The entries come later than the opener (the
// app sends its layout) and can change, the list or any entry's text and
// state; the copy here follows them at most every 250 ms, the first
// TRAY_MENU_MAX entries only. Each entry copied with the same names as the
// entry itself: { entry (the QsMenuEntry, for triggered() and its
// submenu), text (cleaned), enabled, isSeparator, hasChildren, check (""
// none, "check", "radio"), checked }. Only text and state are kept: no
// icon from the app. live() reads the same, now, with no wait (the ×
// checks the entry again right before it acts).
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
    // A change of any entry shown (text, enabled, kind, state) is read too
    Instantiator {
        model: root.menu ? Lists.toList(opener.children.values, Lists.TRAY_MENU_MAX) : []
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onTextChanged() { root.schedule() }
            function onEnabledChanged() { root.schedule() }
            function onIsSeparatorChanged() { root.schedule() }
            function onHasChildrenChanged() { root.schedule() }
            function onButtonTypeChanged() { root.schedule() }
            function onCheckStateChanged() { root.schedule() }
        }
    }

    // The entries of the level before: a list still holding them is an
    // answer for that level, not this one, and is not taken
    property var stale: []
    onMenuChanged: {
        stale = copy.map(c => c.entry)
        copy = []
        schedule()
    }

    function read(e) {
        return {
            entry: e,
            text: Lists.trayText(e.text),
            enabled: e.enabled === true,
            isSeparator: e.isSeparator === true,
            hasChildren: e.hasChildren === true,
            check: e.buttonType === QsMenuButtonType.CheckBox ? "check" : e.buttonType === QsMenuButtonType.RadioButton ? "radio" : "",
            checked: e.checkState === Qt.Checked
        }
    }
    // The level as it is now ([] while it belongs to the level before)
    function live() {
        if (!root.menu || opener.menu !== root.menu)
            return []
        const list = Lists.toList(opener.children.values, Lists.TRAY_MENU_MAX)
        if (stale.length > 0 && list.some(e => stale.includes(e)))
            return []
        return list.map(read)
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
        const now = live()
        if (now.length > 0)
            stale = []
        copy = now
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
