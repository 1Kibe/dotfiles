import QtQuick
import qs.theme

// Password pill of the lock and login screens: lock icon, three dots while
// something is typed (never how many characters), the Enter arrow, and the
// line under it (checking, wrong password, too many attempts, Caps Lock).
// Shared with the login screen: the caller owns the state and gets the
// password through `submitted`, once, on Enter.
Column {
    id: root

    // ── From the caller ──
    property bool checking: false
    property string error: ""          // "" | "wrong" | "tooMany" | "unknown"
    property int retryMinutes: 0
    property bool capsLock: false
    // Another screen's field has text (the dots show on every screen)
    property bool othersTyping: false
    // Size of the pill (the login screen's is smaller)
    property int fieldWidth: Theme.lockFieldWidth
    property int fieldHeight: Theme.lockFieldHeight

    // Enter with text. The field is emptied right after: the caller keeps
    // the password only until it hands it to PAM.
    signal submitted(string password)
    // The field went from empty to typed or back (for othersTyping)
    signal typingChanged(bool typing)
    // Esc (the field is also emptied): the login screen closes its menus
    signal cancelled()
    // Left or right with the field empty: the login screen changes user
    signal sideKey(int step)

    readonly property bool lockedOut: error === "tooMany"
    readonly property bool hasText: input.text.length > 0

    function focusField() {
        input.forceActiveFocus()
    }

    function clearField() {
        input.clear()
    }

    // A wrong password: the pill shakes sideways
    function shake() {
        shaking.restart()
    }

    spacing: 10

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth
        height: root.fieldHeight
        radius: height / 2
        color: Theme.lockFieldFill
        border.width: root.error === "wrong" || root.error === "unknown" ? 2 : 0
        border.color: Theme.red
        opacity: root.lockedOut ? Theme.lockLockedOpacity : 1

        transform: Translate {
            id: offset
        }

        // 10 → −10 → 6 → −6 → 0 px, about 0.3 s
        SequentialAnimation {
            id: shaking
            NumberAnimation { target: offset; property: "x"; to: Theme.lockShake; duration: 50 }
            NumberAnimation { target: offset; property: "x"; to: -Theme.lockShake; duration: 70 }
            NumberAnimation { target: offset; property: "x"; to: Theme.lockShake * 0.6; duration: 60 }
            NumberAnimation { target: offset; property: "x"; to: -Theme.lockShake * 0.6; duration: 60 }
            NumberAnimation { target: offset; property: "x"; to: 0; duration: 50 }
        }

        Text {
            id: lockIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌾"
            color: Theme.fg4
            font.family: Theme.font
            font.pixelSize: 18
        }

        // The real input, invisible: NoEcho keeps the text in memory only
        // and draws nothing; the dots below say "typing" without a count
        TextInput {
            id: input
            anchors.left: lockIcon.right
            anchors.right: arrow.left
            anchors.margins: 12
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.NoEcho
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            readOnly: root.checking || root.lockedOut
            focus: true
            color: Theme.clear
            selectionColor: Theme.clear
            cursorVisible: false
            cursorDelegate: Item {}

            onTextChanged: root.typingChanged(text.length > 0)

            Keys.onReturnPressed: root.send()
            Keys.onEnterPressed: root.send()
            Keys.onEscapePressed: {
                input.clear()
                root.cancelled()
            }
            Keys.onLeftPressed: event => {
                if (input.text.length === 0)
                    root.sideKey(-1)
                else
                    event.accepted = false
            }
            Keys.onRightPressed: event => {
                if (input.text.length === 0)
                    root.sideKey(1)
                else
                    event.accepted = false
            }
        }

        // Placeholder, or three dots that pulse while typing (on any screen)
        Text {
            anchors.centerIn: input
            visible: !root.hasText && !root.othersTyping && !root.checking
            text: root.lockedOut ? "Aguarde" : "Senha"
            color: Theme.fg4
            font.family: Theme.font
            font.pixelSize: 15
        }

        Row {
            id: dots
            anchors.centerIn: input
            spacing: 8
            visible: (root.hasText || root.othersTyping) && !root.checking

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.text

                    SequentialAnimation on opacity {
                        running: dots.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 150 }
                        NumberAnimation { from: 0.3; to: 1; duration: 300 }
                        NumberAnimation { from: 1; to: 0.3; duration: 300 }
                        PauseAnimation { duration: (2 - index) * 150 }
                    }
                }
            }
        }

        // Checking: a turning spinner and the word
        Row {
            anchors.centerIn: input
            visible: root.checking
            spacing: 8

            Text {
                id: spinner
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f0772}"
                color: Theme.fg4
                font.family: Theme.font
                font.pixelSize: 15

                RotationAnimation on rotation {
                    running: root.checking
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Theme.spinnerPeriod
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Conferindo…"
                color: Theme.fg4
                font.family: Theme.font
                font.pixelSize: 15
            }
        }

        // Enter arrow: same as the key
        Rectangle {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 12
            height: width
            radius: width / 2
            color: arrowMouse.containsMouse && root.hasText ? Theme.veil : Theme.clear

            Text {
                anchors.centerIn: parent
                text: "󰁔"
                color: root.hasText ? Theme.text : Theme.fg4
                font.family: Theme.font
                font.pixelSize: 18
            }

            MouseArea {
                id: arrowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.hasText ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.send()
            }
        }
    }

    // One fixed line under the pill: never PAM's own text
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        // Never narrower than the lock's: the long message fits in one line
        width: Math.max(root.fieldWidth, Theme.lockFieldWidth) + 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        visible: text !== ""
        text: root.error === "wrong" ? "Senha incorreta"
            : root.error === "tooMany" ? `Muitas tentativas erradas. Tente de novo em ${root.retryMinutes} min.`
            : root.error === "unknown" ? "Não foi possível verificar a senha"
            : ""
        color: root.error === "tooMany" ? Theme.yellow : Theme.red
        font.family: Theme.font
        font.pixelSize: 14
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.capsLock
        text: "󰌎  Caps Lock ligado"
        color: Theme.yellow
        font.family: Theme.font
        font.pixelSize: 14
    }

    // The field is emptied as soon as the password is handed over
    function send() {
        if (input.text.length === 0 || root.checking || root.lockedOut)
            return
        const password = input.text
        input.clear()
        root.submitted(password)
    }
}
