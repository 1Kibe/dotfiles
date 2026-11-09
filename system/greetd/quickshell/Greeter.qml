import QtQuick
import Quickshell
import qs.theme
import qs.lock
import qs.greeter
import "lock/text.js" as Clean

// The login screen, one window (cage shows it full screen on the last
// monitor). Same look as the lock screen: the shared background with a
// veil, the big clock, the user picture and the password field. Around
// them: the session menu (top left), the status pill (top right), the user
// switcher (arrows or a click on a neighbor) and the power buttons (bottom
// right; reboot and power off ask for a second click). The users show their
// initial only: the greeter never decodes a picture from a user's folder.
FloatingWindow {
    id: window

    color: Theme.bgDeep

    // "reboot" | "poweroff" while waiting for the second click
    property string armed: ""
    property bool sessionsOpen: false
    // -1 or 1: the side the new user slides in from
    property int lastStep: 1

    function closeMenus() {
        sessionsOpen = false
        armed = ""
    }

    function changeUser(step) {
        if (GreeterState.users.length < 2 || GreeterState.checking)
            return
        closeMenus()
        lastStep = step
        GreeterState.nextUser(step)
        slide.restart()
        field.clearField()
        field.focusField()
    }

    function sessionIcon(id) {
        return id.indexOf("hyprland") >= 0 ? "" : "\u{f0379}"
    }

    Item {
        anchors.fill: parent

        LockBackground {
            anchors.fill: parent
            source: GreeterState.picture
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.loginVeil
        }

        // A click anywhere closes the menus and gives the keys back to the field
        MouseArea {
            anchors.fill: parent
            onClicked: {
                window.closeMenus()
                field.focusField()
            }
        }

        // ── Session (top left) ──
        Rectangle {
            id: sessionPill
            x: Theme.loginEdge
            y: Theme.loginEdge
            width: sessionRow.implicitWidth + 24
            height: sessionRow.implicitHeight + 12
            radius: Theme.pillRadius
            color: sessionMouse.containsMouse ? Theme.loginHighlight : Theme.loginPill
            visible: GreeterState.sessions.length > 0

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: GreeterState.session ? window.sessionIcon(GreeterState.session.id) : ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.loginSmallText + 2
                }
                Text {
                    text: GreeterState.session ? Clean.clean(GreeterState.session.name, 40) : ""
                    textFormat: Text.PlainText
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.loginSmallText
                }
                Text {
                    text: window.sessionsOpen ? "\u{f0143}" : "\u{f0140}"
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pixelSize: Theme.loginSmallText + 2
                }
            }

            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    window.armed = ""
                    window.sessionsOpen = !window.sessionsOpen && !GreeterState.checking
                    field.focusField()
                }
            }
        }

        // The list, under the pill; the current one marked
        Rectangle {
            x: Theme.loginEdge
            y: sessionPill.y + sessionPill.height + Theme.loginPad
            // As wide as the longest name (icon and check mark included), within limits
            width: Math.min(Theme.loginSessionMaxWidth,
                            Math.max(Theme.loginSessionMinWidth, sessionList.widest + 2 * Theme.loginPad))
            height: sessionList.implicitHeight + 2 * Theme.loginPad
            radius: Theme.pillRadius
            color: Theme.loginPill
            visible: window.sessionsOpen
            opacity: window.sessionsOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }

            // Clicks inside do not fall through to the background
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: sessionList
                x: Theme.loginPad
                y: Theme.loginPad
                width: parent.width - 2 * Theme.loginPad
                // Natural width of the widest line
                readonly property real widest: {
                    let w = 0
                    for (let i = 0; i < sessionItems.count; i++) {
                        const item = sessionItems.itemAt(i)
                        if (item)
                            w = Math.max(w, item.implicitWidth)
                    }
                    return w
                }

                Repeater {
                    id: sessionItems
                    model: GreeterState.sessions

                    Rectangle {
                        required property var modelData
                        readonly property bool current: GreeterState.session !== null && modelData.id === GreeterState.session.id
                        implicitWidth: 8 + sessionIconText.implicitWidth + 8 + sessionName.implicitWidth + 12 + checkMark.implicitWidth + 8
                        width: sessionList.width
                        height: 30
                        radius: Theme.loginButtonRadius
                        color: current || itemMouse.containsMouse ? Theme.loginHighlight : Theme.clear

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                id: sessionIconText
                                text: window.sessionIcon(modelData.id)
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.loginSmallText + 2
                            }
                            Text {
                                id: sessionName
                                width: Math.min(implicitWidth, sessionList.width - 8 - sessionIconText.implicitWidth - 8 - 12 - checkMark.implicitWidth - 8)
                                text: Clean.clean(modelData.name, 40)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.loginSmallText
                            }
                        }

                        Text {
                            id: checkMark
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: parent.current ? 1 : 0
                            text: "\u{f012c}"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.loginSmallText + 2
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                GreeterState.selectSession(modelData.id)
                                window.sessionsOpen = false
                                field.focusField()
                            }
                        }
                    }
                }
            }
        }

        // ── Status (top right): layout, network, battery ──
        StatusIcons {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.loginEdge
            layout: GreeterState.layout
        }

        // ── Clock, user, password ──
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -40
            spacing: 36

            BigClock {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                // ‹ neighbor  current  neighbor ›
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.loginChevronGap
                    readonly property bool many: GreeterState.users.length > 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.many
                        text: "\u{f0141}"
                        color: Theme.fg4
                        font.family: Theme.font
                        font.pixelSize: Theme.loginChevron

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.changeUser(-1)
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.loginNeighborGap

                        // The one before (only with three or more people)
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: GreeterState.users.length > 2
                            width: Theme.loginNeighbor
                            height: Theme.loginNeighbor
                            opacity: Theme.loginNeighborOpacity
                            readonly property var user: GreeterState.users.length > 2
                                ? GreeterState.users[(GreeterState.userIndex - 1 + GreeterState.users.length) % GreeterState.users.length] : null

                            UserCard {
                                showName: false
                                size: Theme.loginNeighbor
                                name: parent.user ? parent.user.display : ""
                                usePhoto: false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.changeUser(-1)
                            }
                        }

                        // The current one, with a ring
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.loginAvatar + 2 * (Theme.loginRing + 2)
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.clear
                                border.width: Theme.loginRing
                                border.color: Theme.accentLight
                            }

                            UserCard {
                                id: currentCard
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: slideOffset
                                property real slideOffset: 0
                                showName: false
                                size: Theme.loginAvatar
                                name: GreeterState.current ? GreeterState.current.display : ""
                                usePhoto: false
                            }

                            // A new user slides in from the side of the arrow
                            ParallelAnimation {
                                id: slide
                                NumberAnimation {
                                    target: currentCard
                                    property: "slideOffset"
                                    from: window.lastStep * Theme.loginNeighborGap
                                    to: 0
                                    duration: Theme.animNormal
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: currentCard
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // The one after
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: GreeterState.users.length > 1
                            width: Theme.loginNeighbor
                            height: Theme.loginNeighbor
                            opacity: Theme.loginNeighborOpacity
                            readonly property var user: GreeterState.users.length > 1
                                ? GreeterState.users[(GreeterState.userIndex + 1) % GreeterState.users.length] : null

                            UserCard {
                                showName: false
                                size: Theme.loginNeighbor
                                name: parent.user ? parent.user.display : ""
                                usePhoto: false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.changeUser(1)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.many
                        text: "\u{f0142}"
                        color: Theme.fg4
                        font.family: Theme.font
                        font.pixelSize: Theme.loginChevron

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.changeUser(1)
                        }
                    }
                }

                // "Ryan · 1 de 2"
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.baseline: count.baseline
                        text: GreeterState.current ? Clean.clean(GreeterState.current.display, 60) : ""
                        textFormat: Text.PlainText
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.loginNameText
                    }
                    Text {
                        id: count
                        visible: GreeterState.users.length > 1
                        text: ` · ${GreeterState.userIndex + 1} de ${GreeterState.users.length}`
                        color: Theme.fg4
                        font.family: Theme.font
                        font.pixelSize: Theme.loginSmallText
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: GreeterState.users.length > 1
                    text: "← → troca de usuário"
                    color: Theme.fg4
                    font.family: Theme.font
                    font.pixelSize: Theme.loginHintText
                }
            }

            PasswordField {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                fieldWidth: Theme.loginFieldWidth
                fieldHeight: Theme.loginFieldHeight
                checking: GreeterState.checking
                error: GreeterState.error
                retryMinutes: GreeterState.retryMinutes
                capsLock: GreeterState.capsLock
                onSubmitted: password => {
                    window.closeMenus()
                    GreeterState.submit(password)
                }
                onCancelled: window.closeMenus()
                onSideKey: step => window.changeUser(step)

                Connections {
                    target: GreeterState
                    function onRejected() {
                        field.clearField()
                        field.shake()
                    }
                }
            }
        }

        // ── Power (bottom right): suspend at once; reboot and power off
        // turn into "click again", which goes back by itself or with Esc ──
        Timer {
            id: disarm
            interval: Theme.loginConfirmTimeout
            running: window.armed !== ""
            onTriggered: window.armed = ""
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.loginEdge
            width: window.armed === "" ? buttons.implicitWidth + 2 * Theme.loginPad : confirm.implicitWidth + 28
            height: window.armed === "" ? Theme.loginButton + 2 * Theme.loginPad : Theme.loginConfirmHeight
            radius: window.armed === "" ? Theme.pillRadius : Theme.loginButtonRadius
            color: window.armed === "" ? Theme.loginPill : Theme.danger

            Row {
                id: buttons
                anchors.centerIn: parent
                visible: window.armed === ""
                spacing: 2

                Repeater {
                    model: [
                        { id: "suspend", icon: "\u{f04b2}" },
                        { id: "reboot", icon: "\u{f0709}" },
                        { id: "poweroff", icon: "\u{f0425}" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: Theme.loginButton
                        height: Theme.loginButton
                        radius: Theme.loginButtonRadius
                        color: buttonMouse.containsMouse ? Theme.loginHighlight : Theme.clear

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: modelData.id === "poweroff" ? Theme.red : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.sessionsOpen = false
                                if (modelData.id === "suspend")
                                    GreeterState.power("suspend")
                                else
                                    window.armed = modelData.id
                                field.focusField()
                            }
                        }
                    }
                }
            }

            Text {
                id: confirm
                anchors.centerIn: parent
                visible: window.armed !== ""
                text: window.armed === "reboot" ? "\u{f0709}  Clique de novo para reiniciar"
                    : "\u{f0425}  Clique de novo para desligar"
                color: Theme.red
                font.family: Theme.font
                font.pixelSize: Theme.loginSmallText
            }

            MouseArea {
                anchors.fill: parent
                visible: window.armed !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const action = window.armed
                    window.armed = ""
                    GreeterState.power(action)
                }
            }
        }
    }

    Component.onCompleted: field.focusField()
}
