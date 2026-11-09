import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.state

// Card of a quick print (hypr-print), at the bottom right of the focused
// monitor: the thumbnail, "Copiado · salvo" and three buttons (annotate,
// folder, trash), with a thin 5 s time bar that stops while the mouse is on
// the card. Slides in from the right; a new print replaces it.
PanelWindow {
    id: root

    property bool shown: false
    // Already checked by CaptureState.showCard: a PNG inside Capturas
    readonly property string file: CaptureState.cardFile

    screen: Quickshell.screens.find(s => s.name === CaptureState.focusName) ?? Quickshell.screens[0]
    // Stays mapped until the fade-out ends
    visible: shown || leave.running
    anchors.bottom: true
    anchors.right: true
    margins.bottom: Theme.gap
    margins.right: Theme.gap
    implicitWidth: Theme.captureCardWidth + 20    // room for the slide
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture-card"

    function hide() {
        if (shown) {
            shown = false
            leave.restart()
        }
    }

    Connections {
        target: CaptureState
        // showCard bumps cardSerial for every print, also for the same file
        // again after an edit: the card starts over from the slide-in
        function onCardSerialChanged() {
            if (CaptureState.cardFile === "")
                return
            leave.stop()
            root.shown = true
            card.opacity = 0
            card.x = 40
            enter.restart()
            thumb.source = ""
            thumb.source = `file://${CaptureState.cardFile}`   // reloads after an edit
            time.restart()
        }
        // Emptied by trashCard: the print is gone, so is the card
        function onCardFileChanged() {
            if (CaptureState.cardFile === "")
                root.hide()
        }
        // The editor took over the screen: the card goes away
        function onOpenChanged() {
            if (CaptureState.open)
                root.hide()
        }
    }

    // From x 40 back to its place at 20 (the slide room), fading in
    ParallelAnimation {
        id: enter
        NumberAnimation { target: card; property: "x"; to: 20; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }
    NumberAnimation {
        id: leave
        target: card
        property: "opacity"
        to: 0
        duration: Theme.animFast
        easing.type: Easing.InCubic
    }

    // 5 s, stopped while the mouse is on the card
    NumberAnimation {
        id: time
        target: bar
        property: "width"
        // The card's width minus its 12 px margins
        from: Theme.captureCardWidth - 24
        to: 0
        duration: 5000
        paused: running && hover.hovered
        onFinished: root.hide()
    }

    Rectangle {
        id: card
        x: 20
        width: Theme.captureCardWidth
        height: column.implicitHeight + 24
        radius: Theme.pillRadius
        color: Theme.stripFill

        HoverHandler {
            id: hover
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Thumbnail: a click opens the editor
            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: 8
                color: Theme.alpha(Theme.bgHard, 0.6)

                Image {
                    id: thumb
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    // Decoded at twice the card width (sharp on a 2x screen, not
                    // the full print); no cache, so an edited print shows anew
                    sourceSize.width: Theme.captureCardWidth * 2
                    asynchronous: true
                    cache: false
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptureState.openEditor(root.file)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Copiado · salvo"
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                // The editor opens the overlay, and that hides the card (onOpenChanged)
                CaptureButton {
                    icon: "󰏫"
                    hint: "Anotar"
                    onPressed: CaptureState.openEditor(root.file)
                }
                CaptureButton {
                    icon: "󰉋"
                    hint: "Abrir a pasta"
                    onPressed: {
                        CaptureState.openFolder()
                        root.hide()
                    }
                }
                // Hides through onCardFileChanged once the file is in the trash
                CaptureButton {
                    icon: "󰩹"
                    hint: "Mandar para a lixeira"
                    onPressed: CaptureState.trashCard(root.file)
                }
            }

            // Time left
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 2

                Rectangle {
                    id: bar
                    height: 2
                    width: Theme.captureCardWidth - 24
                    radius: 1
                    color: Theme.accentLight
                }
            }
        }
    }
}
