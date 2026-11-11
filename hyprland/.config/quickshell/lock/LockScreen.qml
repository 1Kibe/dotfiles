import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The lock screen (ext-session-lock): one surface per monitor, also on a
// monitor plugged in while locked. Every surface has the password field, so
// a monitor that goes away (the lid with an external screen) never leaves
// the screen without one. The surface is bgDeep at once; the content fades
// in. Unlocking only follows a PAM success (state/LockState).
Scope {
    // `secure`: the compositor confirmed every screen is covered. That, not
    // the request, is what "locked" means for hypr-travar and stats. A
    // Binding, not a change handler: after a reload the new lock is born
    // already secure, and no change signal would ever arrive.
    Binding {
        target: LockState
        property: "locked"
        value: sessionLock.secure
    }

    WlSessionLock {
        id: sessionLock

        locked: LockState.wanted

        // The compositor denied our lock (another lock holds the session) or
        // ended it: Quickshell has already dropped it, so the state follows
        // (LockState.lockLost never unlocks; it ignores a lock still held)
        onLockStateChanged: LockState.lockLost(locked)

        WlSessionLockSurface {
            id: surface
            color: Theme.bgDeep

            // The keys go to this screen's field as soon as the lock is
            // confirmed. After a reload the new surface does not get the
            // field's focus by itself.
            Connections {
                target: sessionLock
                function onSecureChanged() {
                    if (sessionLock.secure)
                        field.focusField()
                }
            }

            Item {
                id: content
                anchors.fill: parent

                // Fades in when the surface appears, out once PAM said yes
                property bool shown: false
                opacity: shown && !LockState.unlocking ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                }
                Component.onCompleted: {
                    shown = true
                    field.focusField()
                }

                // The picture chosen in the background picker (plain without one)
                LockBackground {
                    anchors.fill: parent
                    source: BackgroundStore.picture
                }

                // A click anywhere gives the keys back to the field; moving
                // the mouse turns the screen back on (screen off after locking)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: field.focusField()
                    onPositionChanged: LockState.activity()
                    onPressed: mouse => {
                        LockState.activity()
                        mouse.accepted = false
                    }
                }

                StatusIcons {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 24
                    layout: LockState.layout
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // A little above the middle, so the music card fits below
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -40
                    spacing: 36

                    BigClock {
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18

                        UserCard {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: LockState.displayName
                            photo: LockState.photo
                        }

                        PasswordField {
                            id: field
                            anchors.horizontalCenter: parent.horizontalCenter
                            onActivity: LockState.activity()
                            checking: LockState.checking
                            error: LockState.error
                            retryMinutes: LockState.retryMinutes
                            capsLock: LockState.capsLock
                            // Dots on this screen while another one has text
                            othersTyping: LockState.typing && !hasText
                            onSubmitted: password => LockState.submit(password)
                            onTypingChanged: typing => LockState.typing = typing

                            Connections {
                                target: LockState
                                function onRejected() {
                                    field.clearField()
                                    field.shake()
                                }
                            }
                        }
                    }
                }

                // Configurações → Bloqueio e login → Mostrar a música
                MediaCard {
                    allowed: !SettingsStore.ready || SettingsStore.get("lockShowMusic") === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                }
            }
        }
    }
}
