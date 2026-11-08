import QtQuick
import qs.theme
import qs.state

// Emoji tab of the strip: big emoji in columns that scroll sideways (like
// the cards). Click or Enter copies (and closes); arrows move.
Item {
    id: root

    property var model: []
    property int selected: 0
    property string emptyText: "Nada encontrado"
    readonly property var current: model.length > 0 ? model[Math.min(selected, model.length - 1)] : null
    readonly property int rows: Math.max(1, Math.floor(height / Theme.emojiCell))

    onModelChanged: {
        selected = 0
        grid.positionViewAtBeginning()
    }

    // Arrow keys and Enter from the search field; true when used
    function key(event) {
        const n = model.length
        if (n === 0)
            return false
        if (event.key === Qt.Key_Left)
            selected = Math.max(0, selected - rows)
        else if (event.key === Qt.Key_Right)
            selected = Math.min(n - 1, selected + rows)
        else if (event.key === Qt.Key_Up)
            selected = Math.max(0, selected - 1)
        else if (event.key === Qt.Key_Down)
            selected = Math.min(n - 1, selected + 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            EmojiStore.pick(current.e)
        else
            return false
        grid.positionViewAtIndex(selected, GridView.Contain)
        return true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => grid.flick(event.angleDelta.y * 8, 0)
    }

    GridView {
        id: grid
        anchors.fill: parent
        flow: GridView.FlowTopToBottom
        cellWidth: Theme.emojiCell
        cellHeight: Theme.emojiCell
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.model

        delegate: Rectangle {
            id: cell

            required property var modelData
            required property int index
            readonly property bool isSelected: index === root.selected

            width: Theme.emojiCell - 4
            height: Theme.emojiCell - 4
            radius: Theme.radius
            color: cellMouse.containsMouse ? Theme.veil : Theme.clear
            border.width: isSelected ? 2 : 0
            border.color: Theme.accentLight

            Text {
                anchors.centerIn: parent
                text: cell.modelData.e
                // The UI font has no emoji: name the color font, not a fallback
                font.family: Theme.emojiFont
                font.pixelSize: Math.round(Theme.emojiCell * 0.58)
            }
            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = cell.index
                onClicked: EmojiStore.pick(cell.modelData.e)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.model.length === 0
        text: EmojiStore.missing ? "Lista de emoji não encontrada (pacote unicode-emoji)"
                                 : !EmojiStore.loaded ? "Carregando…"
                                 : root.emptyText
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
}
