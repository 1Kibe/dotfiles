import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.theme
import qs.state
import "../ui"

// Configurações → Monitores → Arranjo: the screens that are on, in
// proportion, each with its number and port name; the chosen one with an
// accent border, the one under the mouse outlined. Dragging a screen shows
// where it would land: against an edge of another (lined up with its edges
// or center when close), never on top, never apart; the screens it would
// touch light up. Screens that are off (or mirror another) sit in a row
// under it, dotted, and a click chooses them too. Under all that, the
// chosen screen's own rows (MonitorDetails). "Identificar", "Desfazer" and
// "Aplicar" go at the right of the group's title (headerActions). It all
// edits MonitorsApply's draft; only "Aplicar" tries it on the screens
// (with "Manter?" and the way back in 15 s).
ColumnLayout {
    id: root

    spacing: 0

    // ── The arrangement in view ──
    readonly property var boxes: MonitorsApply.boxes(MonitorsApply.draft)
    readonly property var off: MonitorsApply.draft.filter(s => !s.enabled || s.mirror || !s.mode)
    readonly property var on: MonitorsApply.draft.filter(s => s.enabled)
    readonly property real minX: boxes.length ? Math.min(...boxes.map(b => b.x)) : 0
    readonly property real minY: boxes.length ? Math.min(...boxes.map(b => b.y)) : 0
    readonly property real spanW: boxes.length ? Math.max(...boxes.map(b => b.x + b.w)) - minX : 1
    readonly property real spanH: boxes.length ? Math.max(...boxes.map(b => b.y + b.h)) - minY : 1
    readonly property real pad: 28
    readonly property real k: Math.min((area.width - 2 * pad) / Math.max(1, spanW), (area.height - 2 * pad) / Math.max(1, spanH))
    readonly property real ox: (area.width - spanW * k) / 2
    readonly property real oy: (area.height - spanH * k) / 2

    // A drag: the screen moving and the spot it would land on
    property string dragName: ""
    property var dragSpot: null
    // Tela N: its position in the areas (state/AreasState), as on the
    // chosen screen's row and on Identificar
    readonly property var positions: AreasState.place(AreasState.saved, on.map(s => s.name))
    function number(name) {
        return positions[name] !== undefined ? positions[name] : 0
    }
    function touches(a, b) {
        const side = (a.x + a.w === b.x || b.x + b.w === a.x) && Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) > 0
        const stacked = (a.y + a.h === b.y || b.y + b.h === a.y) && Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) > 0
        return side || stacked
    }

    readonly property Component headerActions: Component {
        RowLayout {
            spacing: 6
            Button {
                text: "Identificar"
                icon: "󰍹"
                onClicked: MonitorsApply.identify()
            }
            Button {
                text: "Desfazer"
                icon: "󰕌"
                opacity: MonitorsApply.dirty ? 1 : 0.4
                onClicked: if (MonitorsApply.dirty) MonitorsApply.resetDraft()
            }
            // The main button: in the accent color when there is something to try
            Rectangle {
                id: applyButton
                readonly property bool ready: MonitorsApply.dirty && MonitorsApply.draftCheck.ok && !MonitorsApply.pending
                implicitWidth: applyText.implicitWidth + 24
                implicitHeight: 28
                radius: Theme.radius
                color: ready ? (applyMouse.containsMouse ? Theme.accentLight : Theme.accent) : Theme.bg1
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }
                Text {
                    id: applyText
                    anchors.centerIn: parent
                    text: "󰄬  Aplicar"
                    color: applyButton.ready ? Theme.bg : Theme.fg4
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: applyButton.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (applyButton.ready) MonitorsApply.applyDraft()
                }
            }
        }
    }

    // ── The drawing ──
    Item {
        id: area
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 12
        implicitHeight: 220

        Repeater {
            model: root.boxes

            Rectangle {
                id: tile
                required property var modelData
                readonly property bool chosen: MonitorsApply.selected === modelData.name
                readonly property bool moving: root.dragName === modelData.name
                // Lights up when the dragged screen would land against it
                readonly property bool joined: root.dragSpot !== null && !moving
                    && root.touches(root.dragSpot, modelData)
                readonly property var at: moving && root.dragSpot ? root.dragSpot : modelData

                x: root.ox + (at.x - root.minX) * root.k
                y: root.oy + (at.y - root.minY) * root.k
                width: modelData.w * root.k
                height: modelData.h * root.k
                radius: Math.max(2, Theme.radius - 2)
                color: moving ? Theme.alpha(Theme.accent, 0.25) : Theme.bg1
                border.width: chosen || joined ? 2 : 1
                border.color: chosen || joined ? Theme.accent : mouse.containsMouse ? Theme.fg4 : Theme.bg2
                z: moving ? 2 : 1

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: String(root.number(tile.modelData.name))
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pixelSize: Math.max(14, Math.min(tile.height * 0.35, 40))
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: Theme.fg4
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.dragName !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point start
                    property bool moved: false
                    onPressed: mouse => {
                        start = mapToItem(area, mouse.x, mouse.y)
                        moved = false
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = mapToItem(area, mouse.x, mouse.y)
                        if (!moved && Math.hypot(p.x - start.x, p.y - start.y) < 4)
                            return
                        moved = true
                        root.dragName = tile.modelData.name
                        root.dragSpot = Object.assign({ w: tile.modelData.w, h: tile.modelData.h },
                            MonitorsApply.snapped(tile.modelData.name,
                                                  Math.round(tile.modelData.x + (p.x - start.x) / root.k),
                                                  Math.round(tile.modelData.y + (p.y - start.y) / root.k)))
                    }
                    onReleased: {
                        const name = tile.modelData.name
                        if (moved && root.dragSpot)
                            MonitorsApply.edit(name, { x: root.dragSpot.x, y: root.dragSpot.y })
                        else
                            MonitorsApply.select(name)
                        root.dragName = ""
                        root.dragSpot = null
                    }
                    onCanceled: {
                        root.dragName = ""
                        root.dragSpot = null
                    }
                }
            }
        }
    }

    // ── Off, or mirroring: outside the arrangement ──
    Flow {
        visible: root.off.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 4
        spacing: 6

        Repeater {
            model: root.off

            Item {
                id: offTile
                required property var modelData
                readonly property bool chosen: MonitorsApply.selected === modelData.name
                width: offRow.implicitWidth + 20
                height: 30
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: offTile.chosen ? Theme.accent : offMouse.containsMouse ? Theme.fg4 : Theme.gray
                        strokeWidth: offTile.chosen ? 2 : 1
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]
                        fillColor: "transparent"
                        PathRectangle {
                            x: 0.5
                            y: 0.5
                            width: offTile.width - 1
                            height: offTile.height - 1
                            radius: Theme.radius
                        }
                    }
                }
                RowLayout {
                    id: offRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: offTile.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.maximumWidth: 140
                        color: Theme.text
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 1
                    }
                    Text {
                        text: offTile.modelData.enabled && offTile.modelData.mirror
                              ? `espelha ${offTile.modelData.mirror}` : "desligada"
                        textFormat: Text.PlainText
                        color: Theme.gray
                        font.family: Theme.fontPanels
                        font.pointSize: Theme.fontSize - 2
                    }
                }
                MouseArea {
                    id: offMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MonitorsApply.select(offTile.modelData.name)
                }
            }
        }
    }

    // Why "Aplicar" is off, a refusal, or local.lua winning over a screen
    Text {
        readonly property string say: MonitorsApply.message !== "" ? MonitorsApply.message
            : MonitorsApply.dirty && !MonitorsApply.draftCheck.ok ? MonitorsApply.draftCheck.error
            : MonitorsApply.warning
        visible: say !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 6
        text: say
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.yellow
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 2
    }

    // The chosen screen's rows
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 1
        color: Theme.bg1
    }
    // By file, like the page's cards (cards/ is not a module of its own)
    Loader {
        Layout.fillWidth: true
        source: Qt.resolvedUrl("MonitorDetails.qml")
    }
}
