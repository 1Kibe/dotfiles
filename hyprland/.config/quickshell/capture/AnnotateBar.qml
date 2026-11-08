import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "tools.js" as Tools

// Under the selection (above it when there is no room): the tools | 5
// colors (a ring on the chosen one) | width 2/3/5/8 (click cycles) | undo /
// redo | save | copy (the default, highlighted).
Rectangle {
    id: root

    property string hint: ""

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.captureButtonHeight + 12
    radius: Theme.pillRadius
    color: Theme.stripFill

    // Clicks on the bar never draw under it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 18
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.bg2
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Tools.TOOLS

            CaptureButton {
                required property var modelData
                readonly property bool isMosaic: modelData.id === "mosaic"
                icon: isMosaic && CaptureState.blurMode ? "󰂵" : modelData.icon
                hint: isMosaic && CaptureState.blurMode ? `Borrar (${modelData.key}; clique de novo: mosaico)` : `${modelData.label} (${modelData.key})`
                active: CaptureState.tool === modelData.id
                onPressed: CaptureState.chooseTool(modelData.id)
                onHoveredChanged: root.hint = hovered ? hint : ""
            }
        }

        Divider {}

        Repeater {
            model: CaptureState.colors

            Rectangle {
                id: swatch

                required property string modelData
                readonly property bool chosen: CaptureState.color === modelData

                implicitWidth: Theme.captureButtonHeight
                implicitHeight: Theme.captureButtonHeight
                radius: width / 2
                color: Theme.clear
                border.width: chosen ? 2 : 0
                border.color: Theme.text

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme[swatch.modelData]
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptureState.color = swatch.modelData
                }
            }
        }

        Divider {}

        // Width: a dot of that size; a click goes to the next one
        CaptureButton {
            hint: `Espessura ${CaptureState.width} px (clique para mudar)`
            onPressed: CaptureState.cycleWidth()
            onHoveredChanged: root.hint = hovered ? hint : ""

            Rectangle {
                anchors.centerIn: parent
                width: CaptureState.width + 4
                height: width
                radius: width / 2
                color: Theme.text
            }
        }

        Divider {}

        CaptureButton {
            icon: "󰕌"
            hint: "Desfazer (Ctrl+Z)"
            enabled: CaptureState.strokes.length > 0
            onPressed: CaptureState.undo()
            onHoveredChanged: root.hint = hovered ? hint : ""
        }
        CaptureButton {
            icon: "󰑎"
            hint: "Refazer (Ctrl+Shift+Z)"
            enabled: CaptureState.redoStack.length > 0
            onPressed: CaptureState.redo()
            onHoveredChanged: root.hint = hovered ? hint : ""
        }

        Divider {}

        CaptureButton {
            icon: "󰆓"
            hint: "Salvar (Ctrl+S)"
            onPressed: CaptureState.exportRequested(false)
            onHoveredChanged: root.hint = hovered ? hint : ""
        }
        CaptureButton {
            icon: "󰆏"
            label: "Copiar"
            hint: "Copiar e salvar (Enter)"
            active: true
            onPressed: CaptureState.exportRequested(true)
            onHoveredChanged: root.hint = hovered ? hint : ""
        }
    }

    // What the hovered button does
    Rectangle {
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: hintText.implicitWidth + 16
        height: hintText.implicitHeight + 8
        radius: height / 2
        color: Theme.stripFill
        visible: root.hint !== ""

        Text {
            id: hintText
            anchors.centerIn: parent
            text: root.hint
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }
    }
}
