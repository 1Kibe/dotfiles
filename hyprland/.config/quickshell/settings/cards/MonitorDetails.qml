import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../monitors.js" as Monitors

// The chosen screen (Configurações → Monitores, under the arrangement):
// "Tela N · <port>" with "Usar esta tela", then its resolution, rate,
// scale, rotation and mirror. Every change goes to the page's draft
// (MonitorsApply.edit); nothing reaches Hyprland until "Aplicar". The first
// row is drawn here, like an OptionRow, so the port name is plain text; the
// monitor's description is not shown.
ColumnLayout {
    id: root

    spacing: 0

    readonly property var screen: MonitorsApply.draft.find(s => s.name === MonitorsApply.selected) || null
    readonly property var on: MonitorsApply.draft.filter(s => s.enabled)
    // Its position in the areas (state/AreasState): Tela 1 is where area 1
    // starts
    readonly property var positions: AreasState.place(AreasState.saved, on.map(s => s.name))
    readonly property int number: screen && screen.enabled && positions[screen.name] !== undefined ? positions[screen.name] : 0
    readonly property bool usable: screen !== null && screen.enabled && !screen.mirror && screen.mode !== null

    function edit(change) {
        if (screen)
            MonitorsApply.edit(screen.name, change)
    }

    Item {
        visible: root.screen !== null
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + 16
        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, Theme.radius - 2)
            color: headHover.hovered ? Theme.veil : Theme.alpha(Theme.fg, 0)
            Behavior on color {
                ColorAnimation { duration: Theme.dur(Theme.animFast) }
            }
        }
        HoverHandler {
            id: headHover
        }
        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.screen ? (root.number > 0 ? `Tela ${root.number} · ${root.screen.name}` : root.screen.name) : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.text
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    readonly property string say: root.number === 1 ? "Principal · a área 1 começa aqui"
                        : root.screen && !root.screen.enabled ? "Desligada" : ""
                    visible: say !== ""
                    text: say
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: Theme.gray
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 2
                }
                // The other screens can become the first one (the areas'
                // numbers change; the screens stay where they are)
                Text {
                    readonly property bool can: AreasState.firstBlocked === ""
                    visible: root.number > 1 && root.on.length > 1
                    text: can ? "Tornar principal" : `Tornar principal · ${AreasState.firstBlocked}`
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: can ? 1 : 0.6
                    color: can && principalMouse.containsMouse ? Theme.accentLight : Theme.gray
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 2
                    font.underline: principalMouse.containsMouse
                    MouseArea {
                        id: principalMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: parent.can ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (parent.can && root.screen) AreasState.makeFirst(root.screen.name)
                    }
                }
            }
            Text {
                text: "Usar esta tela"
                textFormat: Text.PlainText
                color: Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
            }
            Toggle {
                checked: root.screen !== null && root.screen.enabled
                onToggled: v => root.edit({ enabled: v })
            }
        }
    }
    OptionRow {
        visible: root.usable
        divider: true
        label: "Resolução"
        Dropdown {
            options: root.usable ? Monitors.resolutions(root.screen.modes) : []
            value: root.usable ? `${root.screen.mode.w}x${root.screen.mode.h}` : ""
            onPicked: v => {
                const [w, h] = v.split("x").map(Number)
                const rate = Monitors.rates(root.screen.modes, w, h)[0]
                if (rate)
                    root.edit({ mode: { w: w, h: h, r: rate.value } })
            }
        }
    }
    OptionRow {
        visible: root.usable
        divider: true
        label: "Taxa de atualização"
        Dropdown {
            options: root.usable ? Monitors.rates(root.screen.modes, root.screen.mode.w, root.screen.mode.h) : []
            value: root.usable ? (options.find(o => Math.abs(o.value - root.screen.mode.r) < 0.01) || { value: null }).value : null
            onPicked: v => root.edit({ mode: { w: root.screen.mode.w, h: root.screen.mode.h, r: v } })
        }
    }
    OptionRow {
        visible: root.usable
        divider: true
        label: "Escala"
        desc: "Só as que servem nesta resolução"
        Dropdown {
            options: root.usable ? Monitors.scaleChoices(root.screen.mode) : []
            value: root.usable ? root.screen.scale : null
            onPicked: v => root.edit({ scale: v })
        }
    }
    OptionRow {
        visible: root.usable
        divider: true
        label: "Girar"
        Segmented {
            options: [{ value: 0, label: "Normal" }, { value: 1, label: "90°" }, { value: 2, label: "180°" },
                      { value: 3, label: "270°" }]
            value: root.usable ? root.screen.transform : 0
            onPicked: v => root.edit({ transform: v })
        }
    }
    OptionRow {
        visible: root.screen !== null && root.screen.enabled && root.on.length > 1
        divider: true
        label: "Espelhar"
        desc: "Mostra o mesmo que outra tela"
        Dropdown {
            options: [{ value: "", label: "Não" }].concat(
                root.screen ? root.on.filter(s => s.name !== root.screen.name && !s.mirror)
                                     .map(s => ({ value: s.name, label: s.name })) : [])
            value: root.screen ? root.screen.mirror : ""
            onPicked: v => root.edit({ mirror: v })
        }
    }
}
