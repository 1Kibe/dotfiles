import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import qs.lock
import "../ui"

// The user's photo (Configurações → Bloqueio e login): the lock's own user
// card as it shows now, the pictures of the wallpaper gallery's folders to
// pick one from (made into a square, PhotoStore), and "Tirar foto" back to
// the initial. The login screen keeps the initial.
ColumnLayout {
    id: root

    spacing: 10

    Component.onCompleted: {
        PhotoStore.refresh()
        PhotoStore.showTab(PhotoStore.tab)
    }

    RowLayout {
        spacing: 16
        UserCard {
            name: LockState.displayName
            photo: LockState.photo
            size: 72
            showName: false
        }
        ColumnLayout {
            spacing: 6
            Text {
                text: PhotoStore.photo !== "" ? "Aparece no bloqueio." : "Sem foto: o bloqueio mostra a inicial."
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                text: "O login mostra só a inicial."
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
            }
            Button {
                visible: PhotoStore.photo !== ""
                text: "Tirar foto"
                icon: "󰆴"
                onClicked: PhotoStore.remove()
            }
        }
    }

    Segmented {
        options: PhotoStore.tabs.map(t => ({ value: t.id, label: t.label }))
        value: PhotoStore.tab
        onPicked: v => PhotoStore.showTab(v)
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(2, Math.ceil(count / Math.max(1, Math.floor(width / cellWidth)))) * cellHeight
        visible: count > 0
        clip: true
        cellWidth: 96
        cellHeight: 96
        boundsBehavior: Flickable.StopAtBounds
        model: PhotoStore.files

        delegate: Item {
            required property string modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: width / 2
                color: Theme.bg1
                border.width: 2
                border.color: mouse.containsMouse ? Theme.accentLight : Theme.alpha(Theme.accentLight, 0)
                clip: true
                scale: mouse.containsMouse && !Theme.reduceMotion ? 1.03 : 1
                Behavior on border.color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + modelData.split("/").map(encodeURIComponent).join("/")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(176, 176)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !PhotoStore.busy
                    onClicked: PhotoStore.choose(modelData)
                }
            }
        }
    }

    Text {
        visible: grid.count === 0
        text: "Nenhuma imagem aqui"
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    Text {
        visible: PhotoStore.busy || PhotoStore.message !== ""
        text: PhotoStore.busy ? "Preparando a foto…" : PhotoStore.message
        color: PhotoStore.busy ? Theme.fg4 : Theme.red
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
}
