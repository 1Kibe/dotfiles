import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import "../ui"
import "../validate.js" as Validate

// The wallpaper gallery (Configurações → Papel de parede): four folders as
// tabs (WallpaperStore), the pictures of the open one as thumbnails, the
// current one outlined. A click uses it; one from Pasta Imagens or Capturas
// is copied first into Meus papéis (outside the repo, under a name of its
// own). "Escolher arquivo…" adds any image to Meus papéis through the
// system's file chooser. Each tab says what choosing there does. The
// ring moves to the chosen one with a fade and a hovered one grows a little
// (1.03, no growing with reduce motion), all on the Theme's short times.
Item {
    id: root

    implicitHeight: column.implicitHeight

    readonly property string home: Quickshell.env("HOME")
    readonly property string current: SettingsStore.ready ? Validate.expandPath(SettingsStore.get("wallpaper"), home) : ""

    Component.onCompleted: WallpaperStore.showTab(WallpaperStore.tab)

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Segmented {
                options: WallpaperStore.tabs.map(t => ({ value: t.id, label: t.label }))
                value: WallpaperStore.tab
                onPicked: v => WallpaperStore.showTab(v)
            }
            Item { Layout.fillWidth: true }
            Button {
                icon: "󰈔"
                text: WallpaperStore.picking ? "Escolhendo…" : "Escolher arquivo…"
                enabled: !WallpaperStore.busy && !WallpaperStore.picking
                opacity: enabled ? 1 : 0.5
                onClicked: WallpaperStore.pickFile()
            }
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

                PictureFrame {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radius
                    borderColor: modelData === root.current ? Theme.accentLight
                               : mouse.containsMouse ? Theme.bg2 : Theme.alpha(Theme.bg2, 0)
                    colorDuration: Theme.dur(Theme.animNormal)
                    hovered: mouse.containsMouse
                    source: "file://" + modelData.split("/").map(encodeURIComponent).join("/")
                    sourceSize: Qt.size(280, 160)

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
            visible: grid.count === 0 && WallpaperStore.tab !== "imported"
            text: "Nenhuma imagem aqui"
            color: Theme.gray
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            visible: WallpaperStore.busy || WallpaperStore.message !== ""
            text: WallpaperStore.busy ? "Importando…" : WallpaperStore.message
            color: WallpaperStore.busy ? Theme.fg4 : Theme.red
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        // What choosing does here (Meus papéis empty: how to fill it)
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: WallpaperStore.tab === "imported"
                  ? (grid.count === 0 ? "Nenhum papel seu ainda. Use Escolher arquivo…, arraste uma imagem para cá ou escolha uma em Pasta Imagens ou Capturas."
                                      : "Os seus papéis, fora do repo. Escolher arquivo… ou arrastar uma imagem para cá acrescenta outros.")
                  : WallpaperStore.tab === "repo" ? "Os papéis que vêm com os dotfiles. Ao escolher, ele vira o papel de parede."
                  : "Ao escolher, uma cópia vai para Meus papéis."
            color: Theme.gray
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
    }

    // Dropping images from the file manager: they go to Meus papéis
    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: d => {
            if (d.hasUrls && !WallpaperStore.busy) {
                WallpaperStore.importUris(d.urls.map(String))
                d.accept(Qt.CopyAction)
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: drop.containsDrag
            radius: Theme.radius
            color: Theme.alpha(Theme.accent, 0.18)
            Text {
                anchors.centerIn: parent
                text: "Solte para pôr em Meus papéis"
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize
            }
        }
    }

}
