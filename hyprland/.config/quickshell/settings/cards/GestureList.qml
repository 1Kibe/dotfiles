import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../schema.js" as Schema
import "../gestures.js" as Gestures

// Configurações → Gestos: one card per number of fingers (the page's Loader
// sets cardId: "tres" or "quatro"), a row per direction with its list of
// actions (settings/gestures.js). 4 fingers sideways shows the two ways of
// switching areas; picking one sets the areas' mode of Configurações →
// Monitores (the same key), and its row says so. The 4-finger card ends
// with what two fingers do and where the chosen gestures are listed.
ColumnLayout {
    id: root

    property string cardId: "tres"
    readonly property string key: cardId === "quatro" ? "gestures4" : "gestures3"
    readonly property var spec: Schema.KEYS[key]
    readonly property var value: SettingsStore.ready ? (SettingsStore.get(key) || spec.def) : spec.def
    readonly property bool together: SettingsStore.ready ? SettingsStore.get("areasTogether") !== false : true
    readonly property bool locked: LockState.locked || LockState.wanted
    property string message: ""

    spacing: 0

    function labelOf(position, name) {
        const shown = Gestures.shown(position, name, root.together)
        const c = Gestures.choices(root.spec, position).find(o => o.value === shown)
        return c ? c.label : name
    }
    function pick(position, choice) {
        const r = Gestures.picked(root.spec, position, choice)
        if (r === null || root.locked)
            return
        if (r.together !== undefined && r.together !== root.together)
            SettingsStore.set("areasTogether", r.together)
        const next = Object.assign({}, root.value)
        next[position] = r.name
        if (JSON.stringify(next) !== JSON.stringify(root.value))
            SettingsStore.set(root.key, next)
    }

    Connections {
        target: SettingsApply
        function onFailed(key, message) {
            if (key === "gestures3" || key === "gestures4")
                root.message = message
        }
    }

    Repeater {
        model: root.spec.positions

        OptionRow {
            id: row
            required property var modelData
            required property int index
            readonly property string position: modelData.id
            readonly property string name: root.value[position] || root.spec.def[position]
            readonly property string def: root.spec.def[position]

            divider: index > 0
            icon: modelData.icon
            label: modelData.label
            changed: name !== def
            defaultText: root.labelOf(position, def)
            desc: position === "4:side" && name === "areas"
                  ? "“Segue os dedos” separa as áreas por tela, como em Monitores → Áreas de trabalho" : ""
            Dropdown {
                options: Gestures.choices(root.spec, row.position)
                value: Gestures.shown(row.position, row.name, root.together)
                rows: 8
                enabled: !root.locked && SettingsStore.ready
                opacity: enabled ? 1 : 0.5
                onPicked: v => root.pick(row.position, v)
            }
        }
    }

    Text {
        visible: root.cardId === "quatro"
        Layout.fillWidth: true
        Layout.margins: 8
        text: "Dois dedos ficam com rolar e zoom dos apps. A lista do Super+F1 mostra os gestos escolhidos."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
    Text {
        visible: root.message !== ""
        Layout.fillWidth: true
        Layout.margins: 8
        text: root.message
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
