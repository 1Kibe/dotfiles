import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// The bar of Print, on top of the focused monitor: Área / Janela / Tela |
// Foto / Vídeo | (Vídeo) system sound and microphone | delay | OCR |
// (Vídeo) Gravar | Fechar. It drops in when the overlay opens.
Rectangle {
    id: root

    // Hint of the hovered button; hidden ones (sound, mic, record in Foto)
    // are skipped
    property string hint: [bArea, bWin, bScreen, bPhoto, bVideo, bSound, bMic, bRecord, bDelay, bOcr, bClose]
                          .filter(b => b.visible && b.hovered).map(b => b.hint)[0] || ""

    // 8 px around the row of buttons (6 px above and below)
    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.captureButtonHeight + 12
    radius: Theme.pillRadius
    color: Theme.stripFill

    // Drops in from above
    transform: Translate { id: drop }
    onVisibleChanged: {
        if (visible) {
            drop.y = -16
            opacity = 0
            enter.restart()
        }
    }
    ParallelAnimation {
        id: enter
        NumberAnimation { target: drop; property: "y"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Clicks on the bar never start a selection under it
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

        // No mode is lit during OCR (it always takes an area); a click on one
        // goes back to a normal capture (CaptureState.chooseMode)
        CaptureButton {
            id: bArea
            icon: "󰩭"
            label: "Área"
            hint: "Arrastar para escolher uma área"
            active: CaptureState.mode === "area" && CaptureState.purpose !== "ocr"
            onPressed: CaptureState.chooseMode("area")
        }
        CaptureButton {
            id: bWin
            icon: "󰖯"
            label: "Janela"
            hint: "Clicar numa janela"
            active: CaptureState.mode === "window" && CaptureState.purpose !== "ocr"
            onPressed: CaptureState.chooseMode("window")
        }
        CaptureButton {
            id: bScreen
            icon: "󰍹"
            label: "Tela"
            hint: "Clicar num monitor"
            active: CaptureState.mode === "screen" && CaptureState.purpose !== "ocr"
            onPressed: CaptureState.chooseMode("screen")
        }

        Divider {}

        CaptureButton {
            id: bPhoto
            icon: "󰄀"
            hint: "Foto"
            active: CaptureState.kind === "photo"
            onPressed: CaptureState.kind = "photo"
        }
        CaptureButton {
            id: bVideo
            // During a recording this button stops it
            icon: CaptureState.recording ? "󰓛" : "󰕧"
            hint: CaptureState.recording ? "Parar a gravação (Super+Alt+R)" : "Vídeo"
            danger: CaptureState.recording
            active: CaptureState.kind === "video" && !CaptureState.recording
            onPressed: {
                // Stopping also closes this overlay, opened over the recording
                if (CaptureState.recording) {
                    CaptureState.stopRecord()
                    CaptureState.close()
                } else {
                    CaptureState.kind = "video"
                }
            }
        }
        // Saved choices (capture.json), read when the next recording starts
        CaptureButton {
            id: bSound
            visible: CaptureState.kind === "video"
            icon: CaptureState.audioSystem ? "󰕾" : "󰖁"
            hint: CaptureState.audioSystem ? "Som do sistema: ligado" : "Som do sistema: desligado"
            active: CaptureState.audioSystem
            onPressed: CaptureState.audioSystem = !CaptureState.audioSystem
        }
        CaptureButton {
            id: bMic
            visible: CaptureState.kind === "video"
            icon: CaptureState.audioMic ? "󰍬" : "󰍭"
            hint: CaptureState.audioMic ? "Microfone: ligado" : "Microfone: desligado"
            active: CaptureState.audioMic
            onPressed: CaptureState.audioMic = !CaptureState.audioMic
        }
        // Vídeo: start recording the chosen area (or Enter)
        CaptureButton {
            id: bRecord
            visible: CaptureState.kind === "video" && !CaptureState.recording
            icon: "󰑊"
            label: "Gravar"
            hint: "Gravar a área escolhida (Enter)"
            danger: true
            // Same path as Enter: the monitor holding the selection starts it
            // (CaptureOverlay's exportSelection)
            onPressed: CaptureState.exportRequested(true)
        }

        Divider {}

        // 0 → 3 → 5 → 10 s; with a delay a photo goes back to the "choose"
        // phase (pick the mode, then the count runs)
        CaptureButton {
            id: bDelay
            icon: "󱎫"
            label: CaptureState.delay > 0 ? `${CaptureState.delay} s` : ""
            hint: CaptureState.delay > 0 ? `Atraso de ${CaptureState.delay} s (clique para mudar)` : "Sem atraso (clique para 3 s)"
            active: CaptureState.delay > 0
            onPressed: CaptureState.cycleDelay()
        }
        // Turns the open session into OCR (no new overlay); again closes it
        CaptureButton {
            id: bOcr
            icon: "󱄽"
            hint: "Copiar o texto de uma área (Super+Shift+T)"
            active: CaptureState.purpose === "ocr"
            onPressed: CaptureState.openOcr()
        }

        Divider {}

        CaptureButton {
            id: bClose
            icon: "󰅖"
            hint: "Fechar (Esc)"
            onPressed: CaptureState.close()
        }
    }

    // What the hovered button does, or what to do next
    Rectangle {
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: hintText.implicitWidth + 16
        height: hintText.implicitHeight + 8
        radius: height / 2
        color: Theme.stripFill
        visible: hintText.text !== ""

        Text {
            id: hintText
            anchors.centerIn: parent
            // No hover: the next step for the current purpose, kind and phase
            text: root.hint !== "" ? root.hint
                  : CaptureState.purpose === "ocr" ? "Arraste sobre o texto: ele vai para o clipboard"
                  : CaptureState.kind === "video" && !CaptureState.recording ? "Escolha a área e clique em Gravar (ou Enter)"
                  : CaptureState.phase === "choose" ? `Escolha Área, Janela ou Tela (ou Enter): a contagem de ${CaptureState.delay} s começa`
                  : ""
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }
    }
}
