import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import "../ui"
import "../validate.js" as Validate

// The wallpaper gallery (Configurações → Papel de parede): four folders as
// tabs (WallpaperStore), the pictures of the open one as thumbnails, the
// current one outlined. A click uses it; one from Imagens or Capturas is
// imported first (copied outside the repo, under a name of its own). The
// ring moves to the chosen one with a fade and a hovered one grows a little
// (1.03, no growing with reduce motion), all on the Theme's short times.
ColumnLayout {
    id: root

    spacing: 8

    readonly property string home: Quickshell.env("HOME")
    readonly property string current: SettingsStore.ready ? Validate.expandPath(SettingsStore.get("wallpaper"), home) : ""

    Component.onCompleted: WallpaperStore.showTab(WallpaperStore.tab)

    Segmented {
        options: WallpaperStore.tabs.map(t => ({ value: t.id, label: t.label }))
        value: WallpaperStore.tab
        onPicked: v => WallpaperStore.showTab(v)
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(2, Math.ceil(count / Math.max(1, Math.floor(width / cellWidth)))) * cellHeight
        visible: count > 0
        clip: true
        cellWidth: 148
        cellHeight: 92
        boundsBehavior: Flickable.StopAtBounds
        model: WallpaperStore.files

        delegate: Item {
            required property string modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radius
                color: Theme.bg1
                border.width: 2
                border.color: modelData === root.current ? Theme.accentLight
                            : mouse.containsMouse ? Theme.bg2 : Theme.alpha(Theme.bg2, 0)
                clip: true
                scale: mouse.containsMouse && !Theme.reduceMotion ? 1.03 : 1
                Behavior on border.color {
                    ColorAnimation { duration: Theme.dur(Theme.animNormal) }
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
                    sourceSize: Qt.size(280, 160)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !WallpaperStore.busy
                    onClicked: WallpaperStore.choose(modelData)
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
        visible: WallpaperStore.busy || WallpaperStore.message !== ""
        text: WallpaperStore.busy ? "Importando…" : WallpaperStore.message
        color: WallpaperStore.busy ? Theme.fg4 : Theme.red
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    Text {
        visible: WallpaperStore.tab === "pictures" || WallpaperStore.tab === "captures"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Ao escolher, a imagem é copiada para as Importadas (fora do repo)."
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 2
    }
}
