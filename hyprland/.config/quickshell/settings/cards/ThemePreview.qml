import QtQuick
import Quickshell
import qs.theme
import qs.state
import qs.bar
import "../ui"
import "../validate.js" as Validate

// "Tema atual" (Configurações → Tema e cores): the bar and a panel hanging
// from it, in miniature, over the current wallpaper, so the accent, the
// transparency, the corners and the font show as they are now. Drawn with
// the bar's own pieces (BarStrip, AttachedShape) and the Theme's values;
// nothing in it is clickable.
Item {
    id: root

    implicitHeight: 140

    readonly property string home: Quickshell.env("HOME")
    readonly property string wanted: SettingsStore.ready ? Validate.expandPath(SettingsStore.get("wallpaper"), home) : ""
    // The wallpaper once it passed the same check as the desktop's
    property string picture: ""
    onWantedChanged: check()
    Component.onCompleted: check()
    function check() {
        const path = wanted
        if (path === "")
            return
        BackgroundStore.check(path, ok => {
            if (path === root.wanted)
                root.picture = ok ? path : ""
        })
    }

    Rectangle {
        id: screen
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bgDeep
        clip: true

        Image {
            anchors.fill: parent
            visible: root.picture !== "" && status === Image.Ready
            source: root.picture !== "" ? "file://" + root.picture.split("/").map(encodeURIComponent).join("/") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width, height)
        }

        // The bar
        Item {
            id: bar
            x: Theme.gap
            width: parent.width - 2 * Theme.gap
            height: Theme.barHeight

            BarStrip {
                anchors.fill: parent
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle { width: Theme.dotActiveWidth; height: Theme.dotSize; radius: height / 2; color: Theme.dotActive }
                Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: height / 2; color: Theme.dotBusy }
                Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: height / 2; color: Theme.dotEmpty }
            }
            Text {
                anchors.centerIn: parent
                text: Theme.locale.toString(new Date(), "ddd dd/MM  HH:mm")
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰕾  󰤨  󰂄"
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
        }

        // A panel hanging from it
        AttachedShape {
            id: panel
            x: bar.x + bar.width - implicitWidth - 40
            y: Theme.barHeight
            width: implicitWidth
            height: implicitHeight
            bodyWidth: 190
            bodyHeight: 84
            progress: 1
        }
        Column {
            x: panel.x + panel.bodyX + 12
            y: panel.y + 10
            width: panel.bodyWidth - 24
            spacing: 8
            Text {
                text: "Painel"
                color: Theme.text
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize
            }
            Row {
                spacing: 10
                Toggle {
                    checked: true
                    enabled: false
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Destaque"
                    color: Theme.fg4
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                }
            }
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Theme.bg2
                Rectangle {
                    width: parent.width * 0.6
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accentLight
                }
            }
        }
    }
}
