import QtQuick
import qs.state
import "focus.js" as Focus

// The keyboard inside the control center. It holds the keyboard while the
// center shows (nothing else in it takes focus, so the focus stays inside)
// and keeps where the keyboard is: a group (the top line, the grid, the
// sliders, the open section's list, the background apps' chips) and an
// index; the buttons draw their
// ring from keyFocus(). Arrows move inside the group, Tab and Shift+Tab
// between the groups, Enter and Space press the button, Esc folds the
// section and then closes the center. In the sliders (the volume, the
// mixer's arrow, the brightness) ↑/↓ move and ←/→ change the slider by 5%;
// Enter on the volume mutes it, on the arrow folds out the mixer. Opened by a key the ring shows at once, on the first
// button of the grid (or of the power list when it opened there); opened
// by a click it shows only at the first key, which does nothing else.
// Held keys never press twice: a repeated Enter is ignored, so the power
// list's second confirmation always needs a second press.
Item {
    id: root

    // The center showing (open on this monitor)
    required property bool active
    required property string monitorName
    // The grid's buttons drawn (sections.js visible())
    required property var tiles
    // The open section's list (PowerList, NetworkList...): it gives keyCount,
    // keyIndex and pressKey(); null when the open section has none
    property var sectionList: null
    // The sliders (VolumeSlider, BrightnessSlider); null leaves them out
    property var volume: null
    property var brightness: null
    // The background apps' strip (BackgroundStrip): its chips are a group
    // of their own, after the list; null leaves it out
    property var strip: null

    property string group: "grid"
    property int index: 0
    property bool ringVisible: false

    // Pressing a button without a list (Luz noturna): the center does it,
    // the same as a click
    signal toggleRequested(string id)

    readonly property var groups: [
        { name: "top", count: 2, columns: 2 },
        { name: "grid", count: tiles.length, columns: 2 },
        { name: "sliders", count: (volume ? 2 : 0) + (volume && brightness && Brightness.available ? 1 : 0), columns: 1 },
        { name: "list", count: sectionList ? sectionList.keyCount : 0, columns: 1 },
        { name: "strip", count: strip ? strip.chipKeyCount : 0, columns: 1 }
    ]
    function keyFocus(g, i) {
        return active && ringVisible && group === g && index === i
    }
    function place(g, i) {
        const p = Focus.fit(groups, { group: g, index: i })
        group = p.group
        index = p.index
    }

    // Where the keyboard starts at each opening
    function start() {
        ringVisible = ShellState.controlByKey
        if (ShellState.controlSection === "power")
            place("list", 0)
        else
            place("grid", 0)
        keys.forceActiveFocus()
    }
    onActiveChanged: {
        if (active)
            Qt.callLater(start)
        else
            ringVisible = false
    }
    // Super+X with the center open on another section: to the power list
    Connections {
        target: ShellState
        function onControlSectionChanged() {
            if (!root.active)
                return
            if (ShellState.controlSection === "power" && ShellState.controlByKey && root.group !== "top") {
                root.ringVisible = true
                root.place("list", 0)
            }
        }
    }
    // The section whose list the keyboard can reach (for the way back)
    property string listSection: ""
    onSectionListChanged: {
        if (sectionList !== null)
            listSection = ShellState.controlSection
    }
    // The list it was on folded: back to the button of that list (power on
    // the top line, the others in the grid)
    onGroupsChanged: {
        if (group === "list" && groups[3].count === 0) {
            const t = tiles.findIndex(x => x.id === listSection)
            if (t >= 0)
                place("grid", t)
            else
                place("top", 1)
        } else {
            place(group, index)
        }
    }
    // A field inside a list (the Wi-Fi search) gives the keyboard back
    function reclaim() {
        ringVisible = true
        keys.forceActiveFocus()
    }

    function press() {
        if (group === "top") {
            if (index === 0)
                ShellState.toggle("settings", monitorName)
            else
                ShellState.setControlSection("power")
        } else if (group === "grid") {
            const t = tiles[index]
            if (!t)
                return
            if (t.hasList)
                ShellState.setControlSection(t.id)
            else
                toggleRequested(t.id)
        } else if (group === "sliders") {
            if (index === 0)
                volume.toggleMute()
            else if (index === 1)
                ShellState.setControlSection("mixer")
        } else if (group === "list") {
            if (sectionList)
                sectionList.pressKey(index)
        } else if (group === "strip") {
            if (strip)
                strip.pressChipKey(index)
        }
    }

    // What a key does; true when it took it
    function handle(key, modifiers, autoRepeat) {
        if (!active)
            return false
        if (key === Qt.Key_Escape) {
            ShellState.handleEscape()
            return true
        }
        const moves = {}
        moves[Qt.Key_Left] = "left"
        moves[Qt.Key_Right] = "right"
        moves[Qt.Key_Up] = "up"
        moves[Qt.Key_Down] = "down"
        moves[Qt.Key_Tab] = (modifiers & Qt.ShiftModifier) ? "backtab" : "tab"
        moves[Qt.Key_Backtab] = "backtab"
        const isPress = key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space
        if (moves[key] === undefined && !isPress)
            return false
        // The first key after a click only shows where the keyboard is
        if (!ringVisible) {
            ringVisible = true
            return true
        }
        if (isPress) {
            if (!autoRepeat)
                press()
            return true
        }
        // ←/→ on a slider change it (a held key keeps stepping)
        if (group === "sliders" && (key === Qt.Key_Left || key === Qt.Key_Right) && index !== 1) {
            const steps = key === Qt.Key_Right ? 1 : -1
            if (index === 0)
                volume.step(steps)
            else
                brightness.step(steps)
            return true
        }
        const p = Focus.move(groups, { group: group, index: index }, moves[key])
        group = p.group
        index = p.index
        return true
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (root.active && root.handle(event.key, event.modifiers, event.isAutoRepeat))
                event.accepted = true
        }
    }
}
