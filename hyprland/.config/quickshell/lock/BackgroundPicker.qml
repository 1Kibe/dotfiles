import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.state
import qs.bar

// Background of the lock and login screens: three tabs of pictures (the
// repo's wallpapers, Pictures, Capturas), a live preview of the lock screen
// with the blur and darkening controls, and Apply. Session only; opened by
// `qs ipc call lock background` (never while locked). Every picture passes
// state/BackgroundStore's check before Qt opens it.
PanelWindow {
    id: root

    readonly property bool shown: BackgroundStore.pickerOpen
    // Picked in the grid, checked; "" = none yet
    property string selected: ""
    property int selectedWidth: 0
    property int selectedHeight: 0
    property string selectedMime: ""

    screen: Quickshell.screens.find(s => s.name === BackgroundStore.focusName) ?? Quickshell.screens[0]
    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-background-picker"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Opening starts from the picture applied last, when it is still there
    onShownChanged: {
        selected = ""
        if (shown && BackgroundStore.chosen !== "")
            pick(BackgroundStore.chosen)
    }

    // Only a checked file reaches the preview
    function pick(path) {
        BackgroundStore.check(path, (ok, w, h, mime) => {
            if (!ok) {
                BackgroundStore.message = "Esta imagem não pode ser usada"
                return
            }
            BackgroundStore.message = ""
            root.selected = path
            root.selectedWidth = w
            root.selectedHeight = h
            root.selectedMime = mime
        })
    }

    // Check again (the file may have changed), render the final picture with
    // ffmpeg (BackgroundStore.renderFinal), then swap it in
    function apply() {
        if (selected === "" || BackgroundStore.busy)
            return
        BackgroundStore.busy = true
        BackgroundStore.message = ""
        const path = selected
        BackgroundStore.check(path, (ok, w, h, mime) => {
            if (!ok || w <= 0 || h <= 0 || path !== root.selected) {
                root.fail("Esta imagem não pode ser usada")
                return
            }
            if (BackgroundStore.tooBig(w, h)) {
                root.fail("Imagem grande demais")
                return
            }
            BackgroundStore.renderFinal(path, mime, w, h, rendered => {
                if (!rendered) {
                    root.fail("Não deu para gerar o fundo")
                    return
                }
                BackgroundStore.finishApply(path, applied => {
                    BackgroundStore.busy = false
                    if (applied)
                        BackgroundStore.closePicker()
                    else
                        BackgroundStore.message = "Não deu para salvar o fundo"
                })
            })
        })
    }

    function fail(text) {
        BackgroundStore.busy = false
        BackgroundStore.message = text
    }

    // Dimmed screen; a click outside the card closes
    Rectangle {
        anchors.fill: parent
        color: Theme.dim

        MouseArea {
            anchors.fill: parent
            onClicked: BackgroundStore.closePicker()
        }
    }

    Item {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: BackgroundStore.closePicker()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Theme.pickerWidth, root.width - 40)
        height: Math.min(Theme.pickerHeight, root.height - 40)
        radius: Theme.stripRadius
        color: Theme.stripFill

        // Clicks on the card do not reach the dim area below
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // ── Tabs and grid ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Row {
                    spacing: 6

                    Repeater {
                        model: BackgroundStore.tabs

                        Rectangle {
                            required property var modelData
                            readonly property bool active: BackgroundStore.tab === modelData.id
                            width: label.implicitWidth + 24
                            height: 30
                            radius: 15
                            color: active ? Theme.activeFill : tabMouse.containsMouse ? Theme.veil : Theme.clear

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BackgroundStore.showTab(modelData.id)
                            }
                        }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Theme.pickerThumb + 10
                    cellHeight: Theme.pickerThumb * 10 / 16 + 10
                    model: BackgroundStore.files

                    delegate: Item {
                        required property string modelData
                        width: grid.cellWidth
                        height: grid.cellHeight

                        ClippingRectangle {
                            id: thumbBox
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 8
                            color: Theme.bg1
                            border.width: root.selected === modelData ? 3 : 0
                            border.color: Theme.accentLight

                            // Listed files were checked by BackgroundStore. Inside a
                            // ClippingRectangle the parent is its inner item, so the
                            // border comes from the box by id
                            Image {
                                anchors.fill: parent
                                anchors.margins: thumbBox.border.width
                                source: `file://${modelData}`
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                autoTransform: false
                                sourceSize.width: Theme.pickerThumb * 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(modelData)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: "Nenhuma imagem nesta pasta"
                        color: Theme.fg4
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }
            }

            // ── Preview and controls ──
            ColumnLayout {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                spacing: 14

                // The lock screen in small: the picture with the same blur
                // (a fraction of the width) and darkening as the final PNG
                ClippingRectangle {
                    id: preview
                    Layout.preferredWidth: 340
                    Layout.preferredHeight: 340 * 10 / 16
                    radius: 10
                    color: Theme.bgDeep

                    Image {
                        id: previewImage
                        anchors.fill: parent
                        visible: false
                        source: root.selected !== "" ? `file://${root.selected}` : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        autoTransform: false
                        sourceSize.width: 680
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: previewImage
                        visible: previewImage.status === Image.Ready
                        blurEnabled: BackgroundStore.blur > 0
                        blurMax: 32
                        // Radius in px = fraction of the width; 32 is blurMax
                        blur: Math.min(1, BackgroundStore.blurFraction(BackgroundStore.blur) * preview.width / 32)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: BackgroundStore.darken
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -20
                        text: "12:34"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 34
                        font.weight: Font.Light
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 30
                        width: 120
                        height: 20
                        radius: 10
                        color: Theme.lockFieldFill
                    }
                }

                // Desfoque / Escurecer, 0–100%
                Repeater {
                    model: [
                        { label: "Desfoque", key: "blur" },
                        { label: "Escurecer", key: "darken" }
                    ]

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                            }
                            Text {
                                text: `${Math.round(BackgroundStore[modelData.key] * 100)}%`
                                color: Theme.fg4
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }

                        PanelSlider {
                            Layout.fillWidth: true
                            value: BackgroundStore[modelData.key]
                            onMoved: v => BackgroundStore[modelData.key] = v
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: BackgroundStore.message
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: Theme.red
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Cancelar", act: "cancel" },
                            { label: BackgroundStore.busy ? "Aplicando…" : "Aplicar", act: "apply" }
                        ]

                        Rectangle {
                            required property var modelData
                            readonly property bool enabledHere: modelData.act === "cancel"
                                                                || (root.selected !== "" && !BackgroundStore.busy)
                            width: buttonText.implicitWidth + 28
                            height: 34
                            radius: 17
                            color: modelData.act === "apply" && enabledHere ? Theme.activeFill
                                 : buttonMouse.containsMouse ? Theme.veil : Theme.clear
                            opacity: enabledHere ? 1 : 0.5

                            Text {
                                id: buttonText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: buttonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.enabledHere
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.act === "apply" ? root.apply() : BackgroundStore.closePicker()
                            }
                        }
                    }
                }
            }
        }
    }
}
