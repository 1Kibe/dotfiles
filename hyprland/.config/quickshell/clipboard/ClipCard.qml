import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.state

// One clipboard entry: kind on top (and the size of an image), then up to
// five lines of text, a link, code, a color swatch or the image itself.
// Click copies; on hover, pin/unpin and delete in the corner.
Rectangle {
    id: root

    required property var entry
    // Set by ClipStrip for the keyboard selection: thick border and corner buttons
    property bool selected: false
    readonly property bool pinned: entry.pid !== undefined
    // The corner buttons have their own MouseAreas: over them the card stays hovered
    readonly property bool hovered: mouse.containsMouse || pinButton.area.containsMouse || deleteButton.area.containsMouse
    // A pin reads its own file; a history image waits for ClipboardStore.previews
    readonly property string preview: entry.kind === "image" ? (pinned ? `file://${entry.file}` : (ClipboardStore.previews[entry.id] || "")) : ""

    // ClipStrip copies the entry (and the overlay closes)
    signal activated()

    implicitWidth: Theme.cardSize
    implicitHeight: Theme.cardSize
    radius: 10
    color: hovered ? Qt.tint(Theme.cardFill, Theme.veil) : Theme.cardFill
    // The selection border wins over the thin pin border
    border.width: selected ? 2 : pinned ? 1 : 0
    border.color: selected ? Theme.accentLight : Theme.pinBorder
    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    readonly property var labels: ({ text: "Texto", link: "Link", code: "Código", color: "Cor", image: "Imagem" })

    // Asked when the card is created: only cards on screen (and in the
    // ListView cache) decode their image
    Component.onCompleted: {
        if (entry.kind === "image" && !pinned)
            ClipboardStore.requestPreview(entry.id)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: root.entry.kind === "image" ? `${root.labels.image} · ${root.entry.width}×${root.entry.height}` : root.labels[root.entry.kind]
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }

        // Text, link and code: up to five lines, "…" after
        Text {
            visible: root.entry.kind === "text" || root.entry.kind === "link" || root.entry.kind === "code"
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.entry.text
            textFormat: Text.PlainText
            // A link has no spaces to break at
            wrapMode: root.entry.kind === "link" ? Text.WrapAnywhere : Text.Wrap
            maximumLineCount: 5
            elide: Text.ElideRight
            color: root.entry.kind === "link" ? Theme.blue : root.entry.kind === "code" ? Theme.green : Theme.text
            font.family: root.entry.kind === "code" ? Theme.monoFont : Theme.font
            font.pointSize: Theme.fontSize - (root.entry.kind === "code" ? 1 : 0)
        }

        // Color: swatch and value
        ColumnLayout {
            visible: root.entry.kind === "color"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                // Only parsed for a color entry (any other text is no color)
                color: root.entry.kind === "color" ? ClipboardStore.colorOf(root.entry.text) : Theme.clear
                border.width: 1
                border.color: Theme.bg2
            }
            Text {
                textFormat: Text.PlainText
                text: root.entry.text.trim()
                color: Theme.text
                font.family: Theme.monoFont
                font.pointSize: Theme.fontSize
            }
        }

        // Image: preview cropped to the card, a generic icon until (or if not) loaded
        ClippingRectangle {
            visible: root.entry.kind === "image"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: Theme.alpha(Theme.bgHard, 0.5)

            Image {
                id: image
                anchors.fill: parent
                source: root.preview
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Decoded at twice the card width: sharp on HiDPI, light even
                // for a large screenshot
                sourceSize.width: Theme.cardSize * 2
            }
            Text {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                textFormat: Text.PlainText
                text: "󰋩"
                color: Theme.gray
                font.family: Theme.font
                font.pixelSize: 28
            }
        }
    }

    // Corner buttons, on hover
    component CornerButton: Rectangle {
        id: button

        required property string icon
        property color iconColor: Theme.text
        // Exposed so the card can count hover over the button (root.hovered)
        property alias area: area
        signal pressed()

        implicitWidth: 26
        implicitHeight: 26
        radius: Theme.radius
        color: area.containsMouse ? Theme.alpha(Theme.bgHard, 0.95) : Theme.alpha(Theme.bgHard, 0.75)

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: button.icon
            color: button.iconColor
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.pressed()
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        spacing: 4
        // Also shown on the keyboard selection, where Ctrl+P and Del act
        opacity: root.hovered || root.selected ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        CornerButton {
            id: pinButton
            // Yellow while pinned; a click unpins
            icon: "󰐃"
            iconColor: root.pinned ? Theme.yellow : Theme.text
            onPressed: ClipboardStore.togglePin(root.entry)
        }
        CornerButton {
            id: deleteButton
            // A pin goes away by unpinning
            visible: !root.pinned
            icon: "󰅖"
            iconColor: Theme.red
            onPressed: ClipboardStore.remove(root.entry)
        }
    }
}
