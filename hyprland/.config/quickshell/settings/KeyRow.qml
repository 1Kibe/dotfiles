import QtQuick
import QtQuick.Layouts
import qs.state
import "ui"
import "schema.js" as Schema
import "format.js" as Format

// One row of a settings page (SchemaPage): one key, or a pair of keys (a
// control each, centered under the group's columns). The dot and
// "Alterado · padrão …" show while any of them differs from its default; a
// file name pattern shows the name it gives now.
OptionRow {
    id: row

    property var keys: []
    readonly property var spec: Schema.KEYS[keys[0]]
    function valueOf(k) {
        return SettingsStore.ready ? SettingsStore.values[k] : Schema.KEYS[k].def
    }
    readonly property var value: valueOf(keys[0])
    readonly property var changedKeys: keys.filter(k => JSON.stringify(valueOf(k)) !== JSON.stringify(Schema.KEYS[k].def))

    label: spec.label
    changed: changedKeys.length > 0
    defaultText: keys.map(k => Format.value(Schema.KEYS[k], Schema.KEYS[k].def)).join(" / ")
    // A file name pattern shows the name it gives now
    desc: spec.preview === "fileName" && typeof value === "string" && value !== ""
          ? `Fica assim: ${Qt.formatDateTime(new Date(), value)}.png` : (spec.desc || "")

    RowLayout {
        spacing: 12
        Repeater {
            model: row.keys
            // A pair: each control centered in its column's width
            Item {
                required property string modelData
                Layout.preferredWidth: row.keys.length > 1 ? 150 : control.implicitWidth
                implicitHeight: control.implicitHeight
                KeyControl {
                    id: control
                    key: parent.modelData
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: row.keys.length > 1 ? parent.horizontalCenter : undefined
                    width: Math.min(implicitWidth, parent.width)
                }
            }
        }
    }
}
